const https = require('https');
const { spawn, execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const dns = require('dns');

// Force IPv4 (some VPS don't have IPv6 connectivity)
dns.setDefaultResultOrder('ipv4first');

// =============================================================================
// DOEWAH Telegram Bot v2
// =============================================================================
// Now with:
// - Natural language understanding via orchestrator
// - Slash commands as rigid fallback
// - Auto-pull from GitHub
// - Self-healing on failed updates
// =============================================================================

const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const CHAT_ID = process.env.TELEGRAM_CHAT_ID;
const DOEWAH_DIR = '/root/doewah';
const PROJECTS_DIR = '/root/projects';
const LOGS_DIR = '/root/logs';

// Import orchestrator (will be available after first deploy)
let orchestrator = null;
try {
  orchestrator = require('../orchestrator');
  console.log('Orchestrator loaded, LLM provider:', orchestrator.LLM_PROVIDER);
} catch (e) {
  console.log('Orchestrator not available yet:', e.message);
}

// Validate required env vars
if (!BOT_TOKEN || !CHAT_ID) {
  console.error('ERROR: TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID must be set in /root/doewah/.env');
  process.exit(1);
}

// Ensure directories exist
[PROJECTS_DIR, LOGS_DIR].forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

// =============================================================================
// Auto-Update Mechanism
// =============================================================================

let lastGitCheck = 0;
const GIT_CHECK_INTERVAL = 5 * 60 * 1000; // 5 minutes
let lastKnownCommit = '';

async function checkForUpdates() {
  const now = Date.now();
  if (now - lastGitCheck < GIT_CHECK_INTERVAL) return;
  lastGitCheck = now;

  try {
    // Fetch latest
    execSync('git fetch origin main', { cwd: DOEWAH_DIR, stdio: 'pipe' });

    // Check if we're behind
    const localCommit = execSync('git rev-parse HEAD', { cwd: DOEWAH_DIR, encoding: 'utf8' }).trim();
    const remoteCommit = execSync('git rev-parse origin/main', { cwd: DOEWAH_DIR, encoding: 'utf8' }).trim();

    if (localCommit !== remoteCommit && remoteCommit !== lastKnownCommit) {
      console.log(`Update available: ${localCommit.slice(0, 7)} -> ${remoteCommit.slice(0, 7)}`);
      await applyUpdate(localCommit);
    }
  } catch (e) {
    console.error('Update check failed:', e.message);
  }
}

async function applyUpdate(previousCommit) {
  try {
    // Pull changes
    execSync('git pull origin main', { cwd: DOEWAH_DIR, stdio: 'pipe' });

    // Copy updated bot file
    execSync('cp bot/bot.js /root/claude-bot/', { cwd: DOEWAH_DIR, stdio: 'pipe' });

    // Test if new bot starts (syntax check)
    execSync('node -c /root/claude-bot/bot.js', { stdio: 'pipe' });

    await sendMessage('🔄 *DOEWAH updated*\n\nRestarting with new version...');

    // Restart via systemd
    spawn('systemctl', ['restart', 'claude-bot'], { detached: true, stdio: 'ignore' });

  } catch (e) {
    console.error('Update failed, reverting:', e.message);

    // Revert to previous commit
    try {
      execSync(`git reset --hard ${previousCommit}`, { cwd: DOEWAH_DIR, stdio: 'pipe' });
      execSync('cp bot/bot.js /root/claude-bot/', { cwd: DOEWAH_DIR, stdio: 'pipe' });
      await sendMessage(`⚠️ *Update failed, reverted*\n\n${e.message}`);
    } catch (revertError) {
      await sendMessage(`❌ *Critical: Update and revert both failed*\n\n${revertError.message}`);
    }
  }
}

// =============================================================================
// Telegram API Helpers
// =============================================================================

function sendMessage(text, parseMode = 'Markdown') {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({
      chat_id: CHAT_ID,
      text: text.substring(0, 4000),
      parse_mode: parseMode
    });

    const options = {
      hostname: 'api.telegram.org',
      path: `/bot${BOT_TOKEN}/sendMessage`,
      method: 'POST',
      family: 4,
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data)
      }
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => resolve(body));
    });

    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

// =============================================================================
// GitHub Helpers
// =============================================================================

function getGitHost(account) {
  if (account === 'jvpux' || account === 'jvp-ux') {
    return 'github.com-jvpux';
  }
  return 'github.com-jaslr';
}

function cloneProject(account, repoName) {
  const gitHost = getGitHost(account);
  const actualAccount = account === 'jvpux' ? 'jvp-ux' : account;
  const repoUrl = `git@${gitHost}:${actualAccount}/${repoName}.git`;
  const projectPath = `${PROJECTS_DIR}/${repoName}`;

  if (fs.existsSync(projectPath)) {
    sendMessage(`⚠️ Project "${repoName}" already exists`);
    return;
  }

  sendMessage(`📥 Cloning ${actualAccount}/${repoName}...`);

  try {
    execSync(`git clone ${repoUrl} ${projectPath}`, {
      timeout: 120000,
      stdio: 'pipe'
    });
    sendMessage(`✅ Cloned ${repoName}\n\nCreate context file:\n\`/context ${repoName}\``);
  } catch (e) {
    sendMessage(`❌ Clone failed: ${e.message}`);
  }
}

// =============================================================================
// Slash Command Handlers (Rigid Fallback)
// =============================================================================

function handleStatus() {
  let status = '📊 *DOEWAH Status*\n\n';

  // Active sessions
  try {
    const sessions = execSync('tmux list-sessions 2>/dev/null', { encoding: 'utf8' });
    status += '*Active Sessions:*\n';
    sessions.trim().split('\n').forEach(line => {
      const [name] = line.split(':');
      status += `• \`${name}\`\n`;
    });
  } catch (e) {
    status += '*Active Sessions:* None\n';
  }

  // Projects
  try {
    const projects = fs.readdirSync(PROJECTS_DIR).filter(f => {
      const fullPath = path.join(PROJECTS_DIR, f);
      return fs.statSync(fullPath).isDirectory() && fs.existsSync(path.join(fullPath, '.git'));
    });
    status += `\n*Projects:* ${projects.length}\n`;
    projects.forEach(p => status += `• ${p}\n`);
  } catch (e) {
    status += '\n*Projects:* None\n';
  }

  // Contexts
  const contextsDir = path.join(DOEWAH_DIR, 'contexts');
  if (fs.existsSync(contextsDir)) {
    const contexts = fs.readdirSync(contextsDir).filter(f => f.endsWith('.md') && !f.startsWith('_'));
    status += `\n*Context Files:* ${contexts.length}`;
  }

  sendMessage(status);
}

function handleProjects() {
  try {
    const projects = fs.readdirSync(PROJECTS_DIR).filter(f => {
      const fullPath = path.join(PROJECTS_DIR, f);
      return fs.statSync(fullPath).isDirectory() && fs.existsSync(path.join(fullPath, '.git'));
    });

    if (projects.length === 0) {
      sendMessage('📁 No projects yet.\n\nClone one with:\n`/clone jaslr repo-name`');
    } else {
      let msg = '📁 *Projects:*\n\n';
      projects.forEach(p => {
        const projectPath = path.join(PROJECTS_DIR, p);
        try {
          const pkg = JSON.parse(fs.readFileSync(path.join(projectPath, 'package.json'), 'utf8'));
          msg += `• \`${p}\` v${pkg.version || '?'}\n`;
        } catch {
          msg += `• \`${p}\`\n`;
        }
      });
      sendMessage(msg);
    }
  } catch (e) {
    sendMessage('📁 No projects directory.');
  }
}

function handleLogs(sessionName) {
  const logFile = `${LOGS_DIR}/${sessionName}.log`;
  if (fs.existsSync(logFile)) {
    const content = fs.readFileSync(logFile, 'utf8');
    const lastLines = content.split('\n').slice(-50).join('\n');
    sendMessage(`📄 *Logs: ${sessionName}*\n\n\`\`\`\n${lastLines.substring(0, 3500)}\n\`\`\``);
  } else {
    sendMessage(`❌ No logs for: ${sessionName}`);
  }
}

function handleKill(sessionName) {
  try {
    execSync(`tmux kill-session -t ${sessionName} 2>/dev/null`);
    sendMessage(`🔪 Killed: ${sessionName}`);
  } catch (e) {
    sendMessage(`❌ Could not kill: ${sessionName}`);
  }
}

function handleUpdate() {
  sendMessage('🔄 Checking for updates...');
  lastGitCheck = 0; // Force check
  checkForUpdates();
}

function handleHelp() {
  sendMessage(`🤖 *DOEWAH Commands*

*Just talk to me naturally:*
"Fix the pagination bug in Livna"
"What's the status of Orkon?"
"Clone flashlight-db from jaslr"

*Or use slash commands:*
\`/status\` - System status
\`/projects\` - List projects
\`/clone <account> <repo>\` - Clone repo
\`/logs <session>\` - View logs
\`/kill <session>\` - Kill session
\`/update\` - Pull latest DOEWAH
\`/help\` - This message

*LLM:* ${orchestrator ? orchestrator.LLM_PROVIDER : 'not loaded'}`);
}

// =============================================================================
// Natural Language Handler
// =============================================================================

async function handleNaturalLanguage(text) {
  if (!orchestrator) {
    sendMessage('🤖 Orchestrator not loaded. Use /help for commands.');
    return;
  }

  sendMessage('🤔 Thinking...');

  try {
    const result = await orchestrator.processMessage(text);

    if (result.success) {
      sendMessage(result.response);
    } else {
      sendMessage(`⚠️ ${result.response}`);
    }
  } catch (e) {
    sendMessage(`❌ Error: ${e.message}\n\nUse /help for commands.`);
  }
}

// =============================================================================
// Message Router
// =============================================================================

async function handleMessage(text) {
  const trimmed = text.trim();
  const parts = trimmed.split(/\s+/);
  const command = parts[0].toLowerCase();

  // Check for updates periodically
  checkForUpdates();

  // Slash commands - rigid fallback
  switch (command) {
    case '/status':
      handleStatus();
      return;

    case '/projects':
      handleProjects();
      return;

    case '/clone':
      if (parts.length < 3) {
        sendMessage('Usage: `/clone <account> <repo>`\n\nAccounts: jaslr, jvpux');
        return;
      }
      const account = parts[1].toLowerCase();
      if (account !== 'jaslr' && account !== 'jvpux') {
        sendMessage('Account must be `jaslr` or `jvpux`');
        return;
      }
      cloneProject(account, parts[2]);
      return;

    case '/logs':
      if (parts.length < 2) {
        sendMessage('Usage: `/logs <session-name>`');
        return;
      }
      handleLogs(parts[1]);
      return;

    case '/kill':
      if (parts.length < 2) {
        sendMessage('Usage: `/kill <session-name>`');
        return;
      }
      handleKill(parts[1]);
      return;

    case '/update':
      handleUpdate();
      return;

    case '/help':
    case '/start':
      handleHelp();
      return;
  }

  // If starts with / but not recognized
  if (trimmed.startsWith('/')) {
    sendMessage(`Unknown command: ${command}\n\nUse /help for available commands.`);
    return;
  }

  // Natural language - route to orchestrator
  await handleNaturalLanguage(trimmed);
}

// =============================================================================
// Polling Loop
// =============================================================================

let lastUpdateId = 0;

function pollUpdates() {
  const options = {
    hostname: 'api.telegram.org',
    path: `/bot${BOT_TOKEN}/getUpdates?offset=${lastUpdateId + 1}&timeout=30`,
    method: 'GET',
    family: 4
  };

  const req = https.request(options, (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      try {
        const json = JSON.parse(data);
        if (json.ok && json.result) {
          json.result.forEach(update => {
            lastUpdateId = update.update_id;

            if (update.message &&
              update.message.chat.id.toString() === CHAT_ID &&
              update.message.text) {
              handleMessage(update.message.text);
            }
          });
        }
      } catch (e) {
        console.error('Parse error:', e.message);
      }

      setTimeout(pollUpdates, 1000);
    });
  });

  req.on('error', (e) => {
    console.error('Request error:', e.message);
    setTimeout(pollUpdates, 5000);
  });

  req.setTimeout(35000, () => {
    req.destroy();
    setTimeout(pollUpdates, 1000);
  });

  req.end();
}

// =============================================================================
// Start Bot
// =============================================================================

console.log('DOEWAH Bot v2 starting...');
console.log(`Projects: ${PROJECTS_DIR}`);
console.log(`Logs: ${LOGS_DIR}`);
console.log(`Orchestrator: ${orchestrator ? 'loaded' : 'not available'}`);

sendMessage('🟢 *DOEWAH v2 online*\n\nTalk to me naturally or use /help').then(() => {
  console.log('Startup message sent');
  pollUpdates();
}).catch(err => {
  console.error('Startup failed:', err);
  pollUpdates();
});
