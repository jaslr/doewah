/**
 * LLM Adapter - Abstracts LLM provider for easy swapping
 *
 * Currently supports:
 * - claude: Claude Code CLI (default, uses OAuth)
 * - anthropic: Direct Anthropic API (requires API key)
 *
 * To add new provider:
 * 1. Add case to queryLLM()
 * 2. Implement the provider's API call
 */

const { execSync, spawn, exec } = require('child_process');
const https = require('https');
const dns = require('dns');
const fs = require('fs');

dns.setDefaultResultOrder('ipv4first');

// Which LLM provider to use
const LLM_PROVIDER = process.env.LLM_PROVIDER || 'claude';

/**
 * Query the LLM with a prompt
 * @param {string} prompt - The prompt to send
 * @param {object} options - Options like timeout, workingDir
 * @returns {Promise<string>} - The LLM response
 */
async function queryLLM(prompt, options = {}) {
  const { timeout = 60000, workingDir = '/root' } = options;

  switch (LLM_PROVIDER) {
    case 'claude':
      return queryClaudeCode(prompt, { timeout, workingDir });

    case 'anthropic':
      return queryAnthropicAPI(prompt, { timeout });

    default:
      throw new Error(`Unknown LLM provider: ${LLM_PROVIDER}`);
  }
}

/**
 * Get OAuth token from Claude credentials file
 */
function getClaudeOAuthToken() {
  try {
    const credsPath = '/root/.claude/.credentials.json';
    if (fs.existsSync(credsPath)) {
      const creds = JSON.parse(fs.readFileSync(credsPath, 'utf8'));
      return creds.claudeAiOauth?.accessToken || null;
    }
  } catch (e) {
    console.error('Failed to read Claude credentials:', e.message);
  }
  return null;
}

/**
 * Query using Claude Code CLI
 */
async function queryClaudeCode(prompt, { timeout, workingDir }) {
  return new Promise((resolve, reject) => {
    try {
      // Get OAuth token fresh from credentials file (not from process.env)
      const oauthToken = getClaudeOAuthToken();
      if (!oauthToken) {
        reject(new Error('No Claude OAuth token found. Run: claude setup-token'));
        return;
      }

      // Include both system paths and npm paths - node needs to be findable
      const cleanEnv = {
        HOME: '/root',
        PATH: '/usr/local/bin:/usr/bin:/bin:/root/.npm-global/bin',
        TERM: 'xterm-256color',
        CLAUDE_CODE_OAUTH_TOKEN: oauthToken.trim()
      };

      // Escape prompt for shell (use single quotes and escape internal single quotes)
      const escapedPrompt = prompt.replace(/'/g, "'\\''");

      // Run node with claude CLI script directly (avoids shebang PATH issues)
      const claudeScript = '/usr/lib/node_modules/@anthropic-ai/claude-code/cli.js';
      const result = execSync(
        `node ${claudeScript} -p '${escapedPrompt}'`,
        {
          cwd: workingDir,
          timeout,
          encoding: 'utf8',
          env: cleanEnv
        }
      );
      resolve(result.trim());
    } catch (error) {
      reject(new Error(`Claude Code error: ${error.message}`));
    }
  });
}

/**
 * Query using Claude Code CLI with streaming output
 * @param {string} prompt - The prompt to send
 * @param {object} options - Options including callbacks
 * @returns {Promise<string>} - The full response when complete
 */
async function queryClaudeCodeStreaming(prompt, options = {}) {
  const {
    timeout = 120000,
    workingDir = '/root',
    onChunk = () => {},
    onStep = () => {},
  } = options;

  return new Promise((resolve, reject) => {
    // Debug: Check system state
    console.log('[LLM-DEBUG] === Starting Claude Code streaming ===');
    console.log('[LLM-DEBUG] process.env.PATH:', process.env.PATH);

    // Find node and claude paths
    try {
      const nodePath = execSync('which node', { encoding: 'utf8' }).trim();
      console.log('[LLM-DEBUG] which node:', nodePath);
    } catch (e) {
      console.log('[LLM-DEBUG] which node FAILED:', e.message);
    }

    try {
      const claudePath = execSync('which claude', { encoding: 'utf8' }).trim();
      console.log('[LLM-DEBUG] which claude:', claudePath);
    } catch (e) {
      console.log('[LLM-DEBUG] which claude FAILED:', e.message);
    }

    // Check if files exist
    const claudeScript = '/usr/lib/node_modules/@anthropic-ai/claude-code/cli.js';
    console.log('[LLM-DEBUG] claudeScript exists:', fs.existsSync(claudeScript));
    console.log('[LLM-DEBUG] /usr/bin/node exists:', fs.existsSync('/usr/bin/node'));
    console.log('[LLM-DEBUG] /usr/local/bin/node exists:', fs.existsSync('/usr/local/bin/node'));

    const oauthToken = getClaudeOAuthToken();
    if (!oauthToken) {
      reject(new Error('No Claude OAuth token found. Run: claude setup-token'));
      return;
    }
    console.log('[LLM-DEBUG] OAuth token found: yes (length:', oauthToken.length, ')');

    // Use absolute path for node
    const nodeBin = fs.existsSync('/usr/bin/node') ? '/usr/bin/node' :
                    fs.existsSync('/usr/local/bin/node') ? '/usr/local/bin/node' : 'node';
    console.log('[LLM-DEBUG] Using node binary:', nodeBin);

    // Include both system paths and npm paths
    const cleanEnv = {
      HOME: '/root',
      PATH: '/usr/local/bin:/usr/bin:/bin:/root/.npm-global/bin',
      TERM: 'xterm-256color',
      CLAUDE_CODE_OAUTH_TOKEN: oauthToken.trim()
    };
    // Escape prompt for shell
    const escapedPrompt = prompt.replace(/'/g, "'\\''");

    // Use exec with shell - more reliable than spawn for scripts
    const cmd = `CLAUDE_CODE_OAUTH_TOKEN='${oauthToken.trim()}' claude -p '${escapedPrompt}'`;
    console.log('[LLM-DEBUG] Executing via shell, cmd length:', cmd.length);

    let fullOutput = '';
    let timeoutId = null;

    // Token is already in the command string, don't pass env at all
    const child = exec(cmd, {
      cwd: workingDir,
      maxBuffer: 10 * 1024 * 1024, // 10MB
      timeout: timeout
    });

    console.log('[LLM-DEBUG] Exec initiated, pid:', child.pid);

    child.stdout.on('data', (data) => {
      const chunk = data.toString();
      fullOutput += chunk;
      onChunk(chunk);
    });

    child.stderr.on('data', (data) => {
      const text = data.toString();
      console.log('[LLM-DEBUG] stderr:', text.substring(0, 200));
      if (text.includes('Thinking') || text.includes('...')) {
        onStep(text.trim());
      }
    });

    child.on('close', (code) => {
      console.log('[LLM-DEBUG] Process closed with code:', code);
      if (timeoutId) clearTimeout(timeoutId);
      if (code === 0) {
        resolve(fullOutput.trim());
      } else {
        reject(new Error(`Claude Code exited with code ${code}`));
      }
    });

    child.on('error', (error) => {
      console.log('[LLM-DEBUG] Exec error:', error.code, error.message);
      if (timeoutId) clearTimeout(timeoutId);
      reject(new Error(`Claude Code error: ${error.message}`));
    });
  });
}

/**
 * Query using Anthropic API directly (fallback/alternative)
 */
async function queryAnthropicAPI(prompt, { timeout }) {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    throw new Error('ANTHROPIC_API_KEY not set');
  }

  return new Promise((resolve, reject) => {
    const data = JSON.stringify({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 1024,
      messages: [{ role: 'user', content: prompt }]
    });

    const options = {
      hostname: 'api.anthropic.com',
      path: '/v1/messages',
      method: 'POST',
      family: 4,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01'
      }
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(body);
          if (json.content && json.content[0]) {
            resolve(json.content[0].text);
          } else {
            reject(new Error(`Unexpected API response: ${body}`));
          }
        } catch (e) {
          reject(new Error(`Failed to parse API response: ${e.message}`));
        }
      });
    });

    req.on('error', reject);
    req.setTimeout(timeout, () => {
      req.destroy();
      reject(new Error('API request timeout'));
    });

    req.write(data);
    req.end();
  });
}

/**
 * Check if LLM is available and working
 */
async function healthCheck() {
  try {
    const response = await queryLLM('Respond with just "ok"', { timeout: 10000 });
    return response.toLowerCase().includes('ok');
  } catch (error) {
    console.error('LLM health check failed:', error.message);
    return false;
  }
}

module.exports = {
  queryLLM,
  queryLLMStreaming: queryClaudeCodeStreaming,
  healthCheck,
  LLM_PROVIDER
};
