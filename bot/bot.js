const https = require('https');
const { spawn, execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const dns = require('dns');

// Force IPv4 (some VPS don't have IPv6 connectivity)
dns.setDefaultResultOrder('ipv4first');

// =============================================================================
// DOEWAH Telegram Bot
// =============================================================================
// Commands:
//   /fix <project> <task>     - Fix bug, commit, push, deploy
//   /task <project> <task>    - Run task without auto-deploy
//   /status                   - List active tmux sessions
//   /projects                 - List cloned projects
//   /clone <account> <repo>   - Clone repo (account: jaslr or jvpux)
//   /deploy <project> <target>- Deploy project to target (cf, fly, firebase)
//   /logs <session>           - Get last 50 lines of session log
//   /kill <session>           - Kill a tmux session
//   /help                     - Show all commands
// =============================================================================

const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const CHAT_ID = process.env.TELEGRAM_CHAT_ID;
const PROJECTS_DIR = '/root/projects';
const LOGS_DIR = '/root/logs';

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
// Telegram API Helpers
// =============================================================================

function sendMessage(text, parseMode = 'Markdown') {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({
      chat_id: CHAT_ID,
      text: text.substring(0, 4000), // Telegram limit
      parse_mode: parseMode
    });

    const options = {
      hostname: 'api.telegram.org',
      path: `/bot${BOT_TOKEN}/sendMessage`,
      method: 'POST',
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

function sendDocument(filePath, caption) {
  // For sending log files - simplified version
  const content = fs.readFileSync(filePath, 'utf8').slice(-4000);
  return sendMessage(`${caption}\n\n\`\`\`\n${content}\n\`\`\``);
}

// =============================================================================
// GitHub Helpers
// =============================================================================

function getGitHost(account) {
  // Returns the SSH host alias for the given account
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
    sendMessage(`✅ Cloned ${repoName} from ${actualAccount}`);
  } catch (e) {
    sendMessage(`❌ Failed to clone: ${e.message}`);
  }
}

// =============================================================================
// Task Execution
// =============================================================================

function runClaudeTask(project, task, autoDeploy = false) {
  const timestamp = Date.now();
  const sessionName = `${project}-${timestamp}`;
  const projectPath = `${PROJECTS_DIR}/${project}`;
  const logFile = `${LOGS_DIR}/${sessionName}.log`;

  // Check if project exists
  if (!fs.existsSync(projectPath)) {
    sendMessage(`❌ Project "${project}" not found.\n\nUse \`/projects\` to list available projects or \`/clone <account> <repo>\` to clone one.`);
    return;
  }

  const deployInstructions = autoDeploy 
    ? 'After completing the task, commit your changes with a descriptive message, push to the repository, and deploy if deployment configuration exists.'
    : '';

  const fullTask = `${task}. ${deployInstructions}`.trim();

  sendMessage(`🚀 *Starting task*\n\n*Session:* \`${sessionName}\`\n*Project:* ${project}\n*Task:* ${task}\n*Auto-deploy:* ${autoDeploy ? 'Yes' : 'No'}`);

  // Create the execution script
  const scriptContent = `#!/bin/bash
set -a
source /root/doewah/.env
set +a

cd ${projectPath}

# Pull latest changes
git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true

echo "========================================"
echo "Starting Claude Code task..."
echo "Project: ${project}"
echo "Time: $(date)"
echo "========================================"

# Run Claude Code
claude --dangerously-skip-permissions -p "${fullTask.replace(/"/g, '\\"')}" 2>&1 | tee -a ${logFile}

EXIT_CODE=\$?

echo ""
echo "========================================"
echo "Task completed with exit code: \$EXIT_CODE"
echo "Time: $(date)"
echo "========================================"

# Get last commit info
LAST_COMMIT=$(git log -1 --pretty=format:"%h - %s" 2>/dev/null || echo "No commits")
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")

# Send completion notification
if [ \$EXIT_CODE -eq 0 ]; then
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \\
    -H "Content-Type: application/json" \\
    -d '{
      "chat_id": "${CHAT_ID}",
      "text": "✅ *Task Complete*\\n\\n*Session:* \`'"${sessionName}"'\`\\n*Branch:* '"$BRANCH"'\\n*Last commit:* '"$LAST_COMMIT"'\\n\\nView logs: \`/logs '"${sessionName}"'\`",
      "parse_mode": "Markdown"
    }'
else
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \\
    -H "Content-Type: application/json" \\
    -d '{
      "chat_id": "${CHAT_ID}",
      "text": "❌ *Task Failed*\\n\\n*Session:* \`'"${sessionName}"'\`\\n*Exit code:* '"$EXIT_CODE"'\\n\\nAttach to session: \`tmux attach -t '"${sessionName}"'\`\\nView logs: \`/logs '"${sessionName}"'\`",
      "parse_mode": "Markdown"
    }'
fi
`;

  const scriptPath = `/tmp/${sessionName}.sh`;
  fs.writeFileSync(scriptPath, scriptContent);
  fs.chmodSync(scriptPath, '755');

  // Run in tmux
  spawn('tmux', ['new-session', '-d', '-s', sessionName, scriptPath], {
    detached: true,
    stdio: 'ignore'
  });
}

// =============================================================================
// Command Handlers
// =============================================================================

function handleStatus() {
  try {
    const result = execSync('tmux list-sessions 2>/dev/null', { encoding: 'utf8' });
    const sessions = result.trim().split('\n').map(line => {
      const [name, info] = line.split(':');
      return `• \`${name}\` - ${info.trim()}`;
    }).join('\n');
    sendMessage(`📋 *Active Sessions:*\n\n${sessions}`);
  } catch (e) {
    sendMessage('📋 No active sessions');
  }
}

function handleProjects() {
  try {
    const projects = fs.readdirSync(PROJECTS_DIR).filter(f => {
      const fullPath = path.join(PROJECTS_DIR, f);
      return fs.statSync(fullPath).isDirectory() && fs.existsSync(path.join(fullPath, '.git'));
    });

    if (projects.length === 0) {
      sendMessage('📁 No projects yet.\n\nClone one with:\n`/clone jaslr repo-name`\n`/clone jvpux repo-name`');
    } else {
      const projectList = projects.map(p => {
        try {
          const gitConfig = fs.readFileSync(path.join(PROJECTS_DIR, p, '.git', 'config'), 'utf8');
          const remoteMatch = gitConfig.match(/url = .*[:/]([^/]+)\/([^/\n]+)/);
          const owner = remoteMatch ? remoteMatch[1] : 'unknown';
          return `• \`${p}\` (${owner})`;
        } catch {
          return `• \`${p}\``;
        }
      }).join('\n');
      sendMessage(`📁 *Projects:*\n\n${projectList}`);
    }
  } catch (e) {
    sendMessage('📁 No projects directory yet.');
  }
}

function handleLogs(sessionName) {
  const logFile = `${LOGS_DIR}/${sessionName}.log`;
  if (fs.existsSync(logFile)) {
    const content = fs.readFileSync(logFile, 'utf8');
    const lastLines = content.split('\n').slice(-50).join('\n');
    sendMessage(`📄 *Logs for ${sessionName}:*\n\n\`\`\`\n${lastLines.substring(0, 3500)}\n\`\`\``);
  } else {
    sendMessage(`❌ No log file found for session: ${sessionName}`);
  }
}

function handleKill(sessionName) {
  try {
    execSync(`tmux kill-session -t ${sessionName} 2>/dev/null`);
    sendMessage(`🔪 Killed session: ${sessionName}`);
  } catch (e) {
    sendMessage(`❌ Could not kill session: ${sessionName}`);
  }
}

function handleHelp() {
  sendMessage(`🤖 *DOEWAH - Claude Runner Commands*

*Task Commands:*
\`/fix <project> <description>\`
Fix a bug, commit, push, and deploy

\`/task <project> <description>\`
Run any task (no auto-deploy)

*Project Commands:*
\`/projects\`
List all cloned projects

\`/clone <account> <repo>\`
Clone a repo (account: jaslr or jvpux)

*Session Commands:*
\`/status\`
List active tmux sessions

\`/logs <session>\`
View last 50 lines of session log

\`/kill <session>\`
Kill a tmux session

*Examples:*
\`/fix flashlight-db Fix pagination on brand list\`
\`/task my-app Add dark mode to settings\`
\`/clone jaslr flashlight-db\`
\`/clone jvpux other-project\`
\`/logs flashlight-db-1704067200\``);
}

// =============================================================================
// Message Router
// =============================================================================

function handleMessage(text) {
  const parts = text.trim().split(/\s+/);
  const command = parts[0].toLowerCase();

  switch (command) {
    case '/fix': {
      if (parts.length < 3) {
        sendMessage('Usage: `/fix <project> <task description>`');
        return;
      }
      const project = parts[1];
      const task = parts.slice(2).join(' ');
      runClaudeTask(project, task, true);
      break;
    }

    case '/task': {
      if (parts.length < 3) {
        sendMessage('Usage: `/task <project> <task description>`');
        return;
      }
      const project = parts[1];
      const task = parts.slice(2).join(' ');
      runClaudeTask(project, task, false);
      break;
    }

    case '/status':
      handleStatus();
      break;

    case '/projects':
      handleProjects();
      break;

    case '/clone': {
      if (parts.length < 3) {
        sendMessage('Usage: `/clone <account> <repo-name>`\n\nAccounts: `jaslr` or `jvpux`');
        return;
      }
      const account = parts[1].toLowerCase();
      const repo = parts[2];
      if (account !== 'jaslr' && account !== 'jvpux') {
        sendMessage('Account must be `jaslr` or `jvpux`');
        return;
      }
      cloneProject(account, repo);
      break;
    }

    case '/logs': {
      if (parts.length < 2) {
        sendMessage('Usage: `/logs <session-name>`');
        return;
      }
      handleLogs(parts[1]);
      break;
    }

    case '/kill': {
      if (parts.length < 2) {
        sendMessage('Usage: `/kill <session-name>`');
        return;
      }
      handleKill(parts[1]);
      break;
    }

    case '/help':
    case '/start':
      handleHelp();
      break;

    default:
      if (text.startsWith('/')) {
        sendMessage(`Unknown command. Use /help to see available commands.`);
      }
  }
}

// =============================================================================
// Polling Loop
// =============================================================================

let lastUpdateId = 0;

function pollUpdates() {
  const options = {
    hostname: 'api.telegram.org',
    path: `/bot${BOT_TOKEN}/getUpdates?offset=${lastUpdateId + 1}&timeout=30`,
    method: 'GET'
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

            // Only respond to messages from authorized chat
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

      // Continue polling
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

console.log('DOEWAH Bot starting...');
console.log(`Projects directory: ${PROJECTS_DIR}`);
console.log(`Logs directory: ${LOGS_DIR}`);

sendMessage('🟢 *DOEWAH is online*\n\nUse /help to see commands.').then(() => {
  console.log('Startup message sent, beginning polling...');
  pollUpdates();
}).catch(err => {
  console.error('Failed to send startup message:', err);
  pollUpdates();
});
