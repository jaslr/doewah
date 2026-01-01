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

const { execSync, spawn } = require('child_process');
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
      const oauthToken = getClaudeOAuthToken();
      if (!oauthToken) {
        reject(new Error('No Claude OAuth token found. Run: claude setup-token'));
        return;
      }

      // Escape prompt for shell
      const escapedPrompt = prompt.replace(/'/g, "'\\''");

      // Set token in env and run claude with sandbox mode and skip permissions
      const result = execSync(
        `IS_SANDBOX=1 CLAUDE_CODE_OAUTH_TOKEN='${oauthToken.trim()}' claude --dangerously-skip-permissions -p '${escapedPrompt}'`,
        {
          cwd: workingDir,
          timeout,
          encoding: 'utf8',
          stdio: ['pipe', 'pipe', 'pipe']  // Explicit stdio pipes
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
 * Uses spawn to get real-time output
 */
async function queryClaudeCodeStreaming(prompt, options = {}) {
  const {
    timeout = 300000,
    workingDir = '/root',
    onChunk = () => {},
    onStep = () => {},
  } = options;

  return new Promise((resolve, reject) => {
    const oauthToken = getClaudeOAuthToken();
    if (!oauthToken) {
      reject(new Error('No Claude OAuth token found. Run: claude setup-token'));
      return;
    }

    let fullOutput = '';
    let timeoutHandle;

    // Spawn claude process
    const proc = spawn('claude', ['--dangerously-skip-permissions', '-p', prompt], {
      cwd: workingDir,
      env: {
        ...process.env,
        IS_SANDBOX: '1',
        CLAUDE_CODE_OAUTH_TOKEN: oauthToken.trim(),
      },
    });

    // Set timeout
    timeoutHandle = setTimeout(() => {
      proc.kill('SIGTERM');
      reject(new Error('Claude Code timeout'));
    }, timeout);

    // Stream stdout
    proc.stdout.on('data', (data) => {
      const text = data.toString();
      fullOutput += text;
      onChunk(text);
    });

    // Stream stderr (for progress/steps)
    proc.stderr.on('data', (data) => {
      const text = data.toString();
      // Parse step info if present
      if (text.includes('⠋') || text.includes('⠙') || text.includes('Running')) {
        onStep(text.trim());
      }
    });

    proc.on('close', (code) => {
      clearTimeout(timeoutHandle);
      if (code === 0) {
        resolve(fullOutput.trim());
      } else {
        reject(new Error(`Claude Code exited with code ${code}`));
      }
    });

    proc.on('error', (err) => {
      clearTimeout(timeoutHandle);
      reject(new Error(`Claude Code error: ${err.message}`));
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
