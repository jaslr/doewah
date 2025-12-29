/**
 * DOEWAH Orchestrator
 *
 * The brain that understands all your projects and routes requests appropriately.
 *
 * Responsibilities:
 * - Load and parse project context files
 * - Interpret natural language messages
 * - Route to appropriate project agent
 * - Maintain awareness of all project states
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const { execSync, spawn } = require('child_process');
const { queryLLM, healthCheck, LLM_PROVIDER } = require('./llm-adapter');

const CONTEXTS_DIR = '/root/doewah/contexts';
const PROJECTS_DIR = '/root/projects';
const LOGS_DIR = '/root/logs';

// ORCHON (Observatory) integration
const ORCHON_URL = process.env.OBSERVATORY_URL || 'https://observatory-backend.fly.dev';
const ORCHON_SECRET = process.env.OBSERVATORY_API_SECRET;

// Sentry integration
const SENTRY_BASE_URL = process.env.SENTRY_BASE_URL || 'https://de.sentry.io';
const SENTRY_AUTH_TOKEN = process.env.SENTRY_AUTH_TOKEN;
const SENTRY_ORG = process.env.SENTRY_ORG;

// Known GitHub accounts and their SSH host aliases
const GITHUB_ACCOUNTS = {
  'jaslr': 'github.com-jaslr',
  'jvpux': 'github.com-jvpux',
  'jvp-ux': 'github.com-jvpux'
};

// =============================================================================
// ORCHON (Observatory) API Client
// =============================================================================

/**
 * Query ORCHON API endpoint
 */
function queryOrchon(endpoint) {
  return new Promise((resolve, reject) => {
    if (!ORCHON_SECRET) {
      reject(new Error('OBSERVATORY_API_SECRET not configured'));
      return;
    }

    const url = new URL(endpoint, ORCHON_URL);

    const options = {
      hostname: url.hostname,
      path: url.pathname + url.search,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${ORCHON_SECRET}`,
        'Content-Type': 'application/json'
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error(`Invalid JSON: ${data.substring(0, 100)}`));
        }
      });
    });

    req.on('error', reject);
    req.setTimeout(10000, () => {
      req.destroy();
      reject(new Error('ORCHON request timeout'));
    });
    req.end();
  });
}

/**
 * Get last deployment failure from ORCHON
 */
async function executeLastFailure() {
  try {
    const result = await queryOrchon('/api/deployments/last-failure');
    if (!result.deployment) {
      return { success: true, response: '✅ No recent deployment failures!' };
    }

    const d = result.deployment;
    const when = d.completedAt ? new Date(d.completedAt).toLocaleString('en-AU', {
      timeZone: 'Australia/Sydney',
      day: 'numeric',
      month: 'short',
      hour: 'numeric',
      minute: '2-digit',
      hour12: true
    }) : 'unknown time';

    return {
      success: true,
      response: `❌ *Last Failure*\n\n*Project:* ${d.projectDisplayName || d.projectName}\n*Provider:* ${d.provider}\n*Branch:* ${d.branch || 'main'}\n*When:* ${when}`
    };
  } catch (e) {
    return { success: false, response: `Failed to query ORCHON: ${e.message}` };
  }
}

/**
 * Get recent failures from ORCHON
 */
async function executeRecentFailures(limit = 5) {
  try {
    const result = await queryOrchon(`/api/deployments/failures?limit=${limit}`);
    if (!result.deployments || result.deployments.length === 0) {
      return { success: true, response: '✅ No recent deployment failures!' };
    }

    let response = `❌ *Recent Failures (${result.deployments.length})*\n\n`;
    for (const d of result.deployments) {
      const when = d.completedAt ? new Date(d.completedAt).toLocaleString('en-AU', {
        timeZone: 'Australia/Sydney',
        day: 'numeric',
        month: 'short',
        hour: 'numeric',
        minute: '2-digit',
        hour12: true
      }) : '?';
      response += `• *${d.projectDisplayName || d.projectName}* (${d.provider}) - ${when}\n`;
    }

    return { success: true, response };
  } catch (e) {
    return { success: false, response: `Failed to query ORCHON: ${e.message}` };
  }
}

/**
 * Get deployment status summary from ORCHON
 */
async function executeDeploymentSummary() {
  try {
    const result = await queryOrchon('/api/status/summary');

    let response = '📊 *Deployment Status*\n\n';
    response += `✅ Healthy: ${result.healthy || 0}\n`;
    response += `⚠️ Degraded: ${result.degraded || 0}\n`;
    response += `❌ Down: ${result.down || 0}\n`;

    if (result.lastFailure) {
      const d = result.lastFailure;
      const when = d.completedAt ? new Date(d.completedAt).toLocaleString('en-AU', {
        timeZone: 'Australia/Sydney',
        day: 'numeric',
        month: 'short',
        hour: 'numeric',
        minute: '2-digit',
        hour12: true
      }) : '?';
      response += `\n*Last failure:* ${d.projectDisplayName || d.projectName} (${when})`;
    }

    return { success: true, response };
  } catch (e) {
    return { success: false, response: `Failed to query ORCHON: ${e.message}` };
  }
}

/**
 * Get recent deployments (all, not just failures) from ORCHON
 */
async function executeRecentDeployments(limit = 10) {
  try {
    const result = await queryOrchon(`/api/deployments/recent?limit=${limit}`);
    if (!result.deployments || result.deployments.length === 0) {
      return { success: true, response: 'No recent deployments found.' };
    }

    let response = `📦 *Recent Deployments (${result.deployments.length})*\n\n`;
    for (const d of result.deployments) {
      const when = (d.deployCompletedAt || d.completedAt)
        ? new Date(d.deployCompletedAt || d.completedAt).toLocaleString('en-AU', {
            timeZone: 'Australia/Sydney',
            day: 'numeric',
            month: 'short',
            hour: 'numeric',
            minute: '2-digit',
            hour12: true
          })
        : '?';
      const icon = d.status === 'success' ? '✅' : d.status === 'failure' ? '❌' : '🔄';
      response += `${icon} *${d.projectDisplayName || d.projectName}* (${d.provider}) - ${when}\n`;
    }

    return { success: true, response };
  } catch (e) {
    return { success: false, response: `Failed to query ORCHON: ${e.message}` };
  }
}

// =============================================================================
// Sentry API Client
// =============================================================================

/**
 * Query Sentry API endpoint
 */
function querySentry(endpoint) {
  return new Promise((resolve, reject) => {
    if (!SENTRY_AUTH_TOKEN) {
      reject(new Error('SENTRY_AUTH_TOKEN not configured'));
      return;
    }

    const url = new URL(endpoint, SENTRY_BASE_URL);

    const options = {
      hostname: url.hostname,
      path: url.pathname + url.search,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${SENTRY_AUTH_TOKEN}`,
        'Content-Type': 'application/json'
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          if (res.statusCode === 200) {
            resolve(JSON.parse(data));
          } else {
            reject(new Error(`Sentry API ${res.statusCode}: ${data.substring(0, 100)}`));
          }
        } catch (e) {
          reject(new Error(`Invalid JSON: ${data.substring(0, 100)}`));
        }
      });
    });

    req.on('error', reject);
    req.setTimeout(15000, () => {
      req.destroy();
      reject(new Error('Sentry request timeout'));
    });
    req.end();
  });
}

/**
 * Format a Sentry issue for Telegram display
 */
function formatSentryIssue(issue) {
  const lastSeen = new Date(issue.lastSeen).toLocaleString('en-AU', {
    timeZone: 'Australia/Sydney',
    day: 'numeric',
    month: 'short',
    hour: 'numeric',
    minute: '2-digit',
    hour12: true
  });

  const location = issue.culprit ? issue.culprit.substring(0, 30) : '/';
  return `• *${issue.shortId}*: ${issue.title.substring(0, 40)}${issue.title.length > 40 ? '...' : ''}\n  └ ${issue.count}x, ${lastSeen}, ${location}`;
}

/**
 * Get Sentry issues for a specific project
 */
async function executeSentryProjectIssues(projectSlug, limit = 5) {
  try {
    if (!SENTRY_ORG) {
      return { success: false, response: 'SENTRY_ORG not configured' };
    }

    const issues = await querySentry(
      `/api/0/projects/${SENTRY_ORG}/${projectSlug}/issues/?statsPeriod=24h&limit=${limit}`
    );

    if (!issues || issues.length === 0) {
      return { success: true, response: `✅ *${projectSlug}*: No Sentry issues in the last 24h` };
    }

    let response = `🔴 *${projectSlug}* (${issues.length} issue${issues.length > 1 ? 's' : ''}, 24h)\n\n`;
    for (const issue of issues.slice(0, limit)) {
      response += formatSentryIssue(issue) + '\n';
    }

    if (issues.length > 0) {
      response += `\n🔗 ${issues[0].permalink.split('/issues/')[0]}/issues/`;
    }

    return { success: true, response };
  } catch (e) {
    return { success: false, response: `Failed to query Sentry: ${e.message}` };
  }
}

/**
 * Get Sentry issues across all configured projects
 */
async function executeSentryAllIssues(limit = 10) {
  try {
    if (!SENTRY_ORG || !SENTRY_AUTH_TOKEN) {
      return { success: false, response: 'Sentry not configured (missing SENTRY_ORG or SENTRY_AUTH_TOKEN)' };
    }

    loadContexts();

    // Find all projects with Sentry configured
    const sentryProjects = [];
    const seen = new Set();
    for (const [key, ctx] of Object.entries(projectContexts)) {
      if (ctx.sentryProject && !seen.has(ctx.sentryProject)) {
        seen.add(ctx.sentryProject);
        sentryProjects.push({ name: ctx.name || key, slug: ctx.sentryProject });
      }
    }

    if (sentryProjects.length === 0) {
      return { success: false, response: 'No projects have Sentry configured' };
    }

    // Query all projects
    const allIssues = [];
    for (const proj of sentryProjects) {
      try {
        const issues = await querySentry(
          `/api/0/projects/${SENTRY_ORG}/${proj.slug}/issues/?statsPeriod=24h&limit=5`
        );
        if (issues && issues.length > 0) {
          for (const issue of issues) {
            issue._projectName = proj.name;
            allIssues.push(issue);
          }
        }
      } catch (e) {
        // Skip projects that fail (might not exist in Sentry)
      }
    }

    if (allIssues.length === 0) {
      return { success: true, response: `✅ No Sentry issues across ${sentryProjects.length} project${sentryProjects.length > 1 ? 's' : ''} (24h)` };
    }

    // Sort by lastSeen
    allIssues.sort((a, b) => new Date(b.lastSeen) - new Date(a.lastSeen));

    let response = `🔴 *Sentry Issues* (${allIssues.length} across ${sentryProjects.length} project${sentryProjects.length > 1 ? 's' : ''})\n\n`;

    let currentProject = null;
    let count = 0;
    for (const issue of allIssues) {
      if (count >= limit) break;

      if (issue._projectName !== currentProject) {
        currentProject = issue._projectName;
        response += `*${currentProject}*:\n`;
      }
      response += formatSentryIssue(issue) + '\n';
      count++;
    }

    return { success: true, response };
  } catch (e) {
    return { success: false, response: `Failed to query Sentry: ${e.message}` };
  }
}

/**
 * Use LLM to interpret a potential Sentry query
 * Handles voice-to-text mishearings like "century" -> "sentry", "liv in a" -> "livna"
 */
async function executeSentryWithLLM(message) {
  try {
    loadContexts();

    // Build list of projects with Sentry configured
    const sentryProjects = [];
    const seen = new Set();
    for (const [key, ctx] of Object.entries(projectContexts)) {
      if (ctx.sentryProject && ctx.name && !seen.has(ctx.name)) {
        seen.add(ctx.name);
        sentryProjects.push({ name: ctx.name, slug: ctx.sentryProject });
      }
    }

    if (sentryProjects.length === 0) {
      return { success: false, response: 'No projects have Sentry monitoring configured.' };
    }

    // Ask LLM to interpret
    const prompt = `You are interpreting a voice message that may contain speech-to-text errors.

User said: "${message}"

Projects with error monitoring:
${sentryProjects.map(p => `- ${p.name}`).join('\n')}

Common mishearings:
- "century" often means "sentry" (error monitoring)
- Project names may be phonetically similar but misspelled

Is this a request about errors/issues/bugs for a specific project?

Reply with ONLY one of these (no explanation):
- The exact project name from the list above
- "ALL" if asking about errors across all projects
- "NO" if this is not about error monitoring at all`;

    const llmResponse = await queryLLM(prompt, { timeout: 15000 });
    const interpreted = llmResponse.trim().toUpperCase();

    // Handle LLM response
    if (interpreted === 'NO') {
      // Not a Sentry query - let it fall through to normal processing
      return { success: false, notSentry: true };
    }

    if (interpreted === 'ALL') {
      return executeSentryAllIssues();
    }

    // Find the matching project
    const matchedProject = sentryProjects.find(
      p => p.name.toUpperCase() === interpreted
    );

    if (matchedProject) {
      return executeSentryProjectIssues(matchedProject.slug);
    }

    // LLM gave an unexpected response - try fuzzy match
    const fuzzyMatch = sentryProjects.find(
      p => interpreted.includes(p.name.toUpperCase()) || p.name.toUpperCase().includes(interpreted)
    );

    if (fuzzyMatch) {
      return executeSentryProjectIssues(fuzzyMatch.slug);
    }

    // Couldn't determine - query all
    return executeSentryAllIssues();

  } catch (e) {
    return { success: false, response: `Failed to interpret query: ${e.message}` };
  }
}

// Cache of loaded project contexts
let projectContexts = {};
let lastContextLoad = 0;
const CONTEXT_RELOAD_INTERVAL = 60000; // Reload contexts every minute

/**
 * Load all project context files
 */
function loadContexts() {
  const now = Date.now();
  if (now - lastContextLoad < CONTEXT_RELOAD_INTERVAL && Object.keys(projectContexts).length > 0) {
    return projectContexts;
  }

  projectContexts = {};

  if (!fs.existsSync(CONTEXTS_DIR)) {
    console.log('No contexts directory found');
    return projectContexts;
  }

  const files = fs.readdirSync(CONTEXTS_DIR).filter(f => f.endsWith('.md') && !f.startsWith('_'));

  for (const file of files) {
    const name = file.replace('.md', '');
    const content = fs.readFileSync(path.join(CONTEXTS_DIR, file), 'utf8');
    const context = parseContextFile(content);
    context.name = name;
    context.filePath = path.join(CONTEXTS_DIR, file);
    projectContexts[name] = context;

    // Also index by aliases
    if (context.aliases) {
      for (const alias of context.aliases) {
        projectContexts[alias.toLowerCase()] = context;
      }
    }
  }

  lastContextLoad = now;
  console.log(`Loaded ${files.length} project contexts`);
  return projectContexts;
}

/**
 * Parse a context markdown file into structured data
 */
function parseContextFile(content) {
  const context = {
    raw: content,
    aliases: [],
    description: '',
    githubAccount: '',
    repoName: '',
    techStack: [],
    deployPlatform: '',
    deployCommand: '',
    productionUrl: '',
    sentryProject: ''
  };

  // Extract aliases
  const aliasMatch = content.match(/## Aliases\n([\s\S]*?)(?=\n##|$)/);
  if (aliasMatch) {
    context.aliases = aliasMatch[1]
      .split('\n')
      .map(line => line.replace(/^-\s*/, '').trim())
      .filter(a => a && !a.startsWith('<!--'));
  }

  // Extract description
  const descMatch = content.match(/## Description\n([\s\S]*?)(?=\n##|$)/);
  if (descMatch) {
    context.description = descMatch[1].trim().split('\n')[0].replace(/<!--.*-->/, '').trim();
  }

  // Extract deploy platform
  const platformMatch = content.match(/\*\*Platform\*\*:\s*(\S+)/);
  if (platformMatch) {
    context.deployPlatform = platformMatch[1];
  }

  // Extract Sentry project
  const sentryMatch = content.match(/\*\*Sentry Project\*\*:\s*(\S+)/);
  if (sentryMatch) {
    context.sentryProject = sentryMatch[1];
  }

  return context;
}

/**
 * Get list of available projects (both with contexts and cloned)
 */
function getAvailableProjects() {
  const projects = new Set();

  // From context files
  loadContexts();
  for (const [name, ctx] of Object.entries(projectContexts)) {
    if (ctx.name) projects.add(ctx.name);
  }

  // From cloned repos
  if (fs.existsSync(PROJECTS_DIR)) {
    const dirs = fs.readdirSync(PROJECTS_DIR).filter(f => {
      const fullPath = path.join(PROJECTS_DIR, f);
      return fs.statSync(fullPath).isDirectory() && fs.existsSync(path.join(fullPath, '.git'));
    });
    dirs.forEach(d => projects.add(d));
  }

  return Array.from(projects);
}

/**
 * Find which project the user is talking about
 */
function identifyProject(message) {
  loadContexts();
  const msgLower = message.toLowerCase();

  // Direct match
  for (const [key, ctx] of Object.entries(projectContexts)) {
    if (msgLower.includes(key.toLowerCase())) {
      return ctx;
    }
  }

  // Check cloned projects
  const projects = getAvailableProjects();
  for (const proj of projects) {
    if (msgLower.includes(proj.toLowerCase())) {
      return projectContexts[proj] || { name: proj, localPath: path.join(PROJECTS_DIR, proj) };
    }
  }

  return null;
}

/**
 * Build system prompt for the orchestrator
 */
function buildSystemPrompt() {
  loadContexts();
  const projects = getAvailableProjects();

  let prompt = `You are DOEWAH, a helpful assistant that manages multiple software projects remotely.

Available projects:
${projects.map(p => {
    const ctx = projectContexts[p];
    if (ctx) {
      return `- ${p}: ${ctx.description || 'No description'} (${ctx.deployPlatform || 'unknown platform'})`;
    }
    return `- ${p}: (no context file)`;
  }).join('\n')}

When the user asks you to do something:
1. Identify which project they're talking about
2. If unclear, ask for clarification
3. For tasks (fix bugs, add features), you'll work in that project's directory
4. For status checks, report what you find

Respond concisely. You're being read on a phone screen.`;

  return prompt;
}

/**
 * Detect if message contains an actionable command
 * Returns: { action: string, params: object } or null
 */
function detectAction(message) {
  const msgLower = message.toLowerCase();

  // Clone detection: "clone jaslr livna" or "clone the livna project from jaslr"
  const clonePatterns = [
    /clone\s+(?:the\s+)?(\w+)\s+(?:from\s+)?(\w+)/i,  // "clone livna from jaslr"
    /clone\s+(\w+)\s+(\w+)/i,                          // "clone jaslr livna"
    /clone\s+(\w+)\/(\w+)/i                            // "clone jaslr/livna"
  ];

  for (const pattern of clonePatterns) {
    const match = message.match(pattern);
    if (match) {
      let [, first, second] = match;
      // Determine which is account and which is repo
      let account, repo;
      if (GITHUB_ACCOUNTS[first.toLowerCase()]) {
        account = first.toLowerCase();
        repo = second;
      } else if (GITHUB_ACCOUNTS[second.toLowerCase()]) {
        account = second.toLowerCase();
        repo = first;
      } else {
        // Default: assume first is account, second is repo
        account = first.toLowerCase();
        repo = second;
      }
      return { action: 'clone', params: { account, repo } };
    }
  }

  // Status detection
  if (msgLower.includes('what projects') || msgLower.includes('list projects')) {
    return { action: 'status', params: {} };
  }

  // ORCHON deployment queries - catch ANY deployment-related question
  // This routes to ORCHON for fast data retrieval instead of LLM guessing

  // Failure-specific queries
  if (msgLower.match(/(?:what|show|any|last|recent)\s*(?:deployment)?\s*fail/i) ||
      msgLower.includes('what broke') ||
      msgLower.includes('what went wrong') ||
      msgLower.includes('any errors') ||
      msgLower.includes('any problems')) {
    if (msgLower.includes('recent') || msgLower.includes('all') || msgLower.includes('show me')) {
      const limitMatch = msgLower.match(/(\d+)/);
      const limit = limitMatch ? parseInt(limitMatch[1], 10) : 5;
      return { action: 'orchon-failures', params: { limit } };
    }
    return { action: 'orchon-last-failure', params: {} };
  }

  // General deployment queries - "last deployment", "recent deployments", "what deployed"
  if (msgLower.match(/(?:what|show|last|recent|latest)\s*(?:was\s*)?(?:the\s*)?deploy/i) ||
      msgLower.match(/deploy(?:ment)?s?\s*(?:lately|recently|today|this week)?/i) ||
      msgLower.includes('what shipped') ||
      msgLower.includes('what went live') ||
      msgLower.includes('what got deployed')) {
    const limitMatch = msgLower.match(/(\d+)/);
    const limit = limitMatch ? parseInt(limitMatch[1], 10) : 10;
    return { action: 'orchon-deployments', params: { limit } };
  }

  // Status/health queries - "how's everything?" "deployment status" "how are things looking?"
  if (msgLower.match(/how(?:'s| is| are)\s*(?:everything|things|deployments?|it|infra)\s*(?:looking|going|doing)?/i) ||
      msgLower.includes('deployment status') ||
      msgLower.includes('infra status') ||
      msgLower.includes('system status') ||
      msgLower.includes('health check') ||
      (msgLower.includes('status') && !msgLower.match(/\b\w+\s+status/))) {
    return { action: 'orchon-summary', params: {} };
  }

  // Version check detection: "what version is livna" or "livna version"
  const versionPatterns = [
    /(?:what|check|get|show)\s+(?:is\s+)?(?:the\s+)?version\s+(?:of\s+)?(\w+)/i,
    /(\w+)\s+version/i,
    /version\s+(?:of\s+)?(\w+)/i
  ];

  for (const pattern of versionPatterns) {
    const match = message.match(pattern);
    if (match) {
      const projectName = match[1].toLowerCase();
      // Check if it's a known project
      loadContexts();
      if (projectContexts[projectName] || fs.existsSync(path.join(PROJECTS_DIR, projectName))) {
        return { action: 'version', params: { project: projectName } };
      }
    }
  }

  // Sentry queries - loose detection, let LLM interpret
  // Catches: sentry, century (voice mishearing), error, issue, bug, broken
  const mightBeSentryQuery = msgLower.match(/sentry|century|error|issue|bug|broken|what.*(wrong|happening)/);

  if (mightBeSentryQuery) {
    return { action: 'sentry-llm-interpret', params: { message } };
  }

  return null;
}

/**
 * Execute a detected action
 */
async function executeAction(action, params) {
  switch (action) {
    case 'clone':
      return executeClone(params.account, params.repo);
    case 'status':
      return executeStatus();
    case 'version':
      return executeVersion(params.project);
    case 'orchon-last-failure':
      return executeLastFailure();
    case 'orchon-failures':
      return executeRecentFailures(params.limit || 5);
    case 'orchon-deployments':
      return executeRecentDeployments(params.limit || 10);
    case 'orchon-summary':
      return executeDeploymentSummary();
    case 'sentry-project':
      return executeSentryProjectIssues(params.slug);
    case 'sentry-all':
      return executeSentryAllIssues();
    case 'sentry-llm-interpret':
      return executeSentryWithLLM(params.message);
    default:
      return { success: false, response: `Unknown action: ${action}` };
  }
}

/**
 * Clone a repository
 */
function executeClone(account, repoName) {
  const gitHost = GITHUB_ACCOUNTS[account] || 'github.com';
  const actualAccount = account === 'jvpux' ? 'jvp-ux' : account;
  const repoUrl = `git@${gitHost}:${actualAccount}/${repoName}.git`;
  const projectPath = path.join(PROJECTS_DIR, repoName);

  if (fs.existsSync(projectPath)) {
    return {
      success: true,
      response: `Project "${repoName}" already exists at ${projectPath}`
    };
  }

  try {
    execSync(`git clone ${repoUrl} ${projectPath}`, {
      timeout: 120000,
      stdio: 'pipe'
    });
    return {
      success: true,
      response: `✅ Cloned ${actualAccount}/${repoName}\n\nLocation: ${projectPath}\n\nNext: Create a context file with /context ${repoName}`
    };
  } catch (e) {
    return {
      success: false,
      response: `❌ Clone failed: ${e.message}\n\nTried: ${repoUrl}`
    };
  }
}

/**
 * Get system status
 */
function executeStatus() {
  let status = '📊 *DOEWAH Status*\n\n';

  // Active tmux sessions
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
  const projects = getAvailableProjects();
  status += `\n*Projects:* ${projects.length}\n`;
  projects.forEach(p => status += `• ${p}\n`);

  // Contexts
  if (fs.existsSync(CONTEXTS_DIR)) {
    const contexts = fs.readdirSync(CONTEXTS_DIR).filter(f => f.endsWith('.md') && !f.startsWith('_'));
    status += `\n*Context Files:* ${contexts.length}`;
  }

  return { success: true, response: status };
}

/**
 * Get version info for a project
 */
function executeVersion(projectName) {
  const projectPath = path.join(PROJECTS_DIR, projectName);

  if (!fs.existsSync(projectPath)) {
    return { success: false, response: `Project "${projectName}" not found` };
  }

  let response = `📦 *${projectName}*\n\n`;

  // Get version from package.json
  try {
    const pkg = JSON.parse(fs.readFileSync(path.join(projectPath, 'package.json'), 'utf8'));
    response += `*Version:* ${pkg.version || 'unknown'}\n`;
  } catch (e) {
    response += '*Version:* No package.json\n';
  }

  // Get last commit
  try {
    const lastCommit = execSync('git log -1 --pretty=format:"%h %s (%ar)"', {
      cwd: projectPath,
      encoding: 'utf8'
    });
    response += `*Last commit:* ${lastCommit}\n`;
  } catch (e) {
    response += '*Last commit:* Unable to read\n';
  }

  // Get branch
  try {
    const branch = execSync('git branch --show-current', {
      cwd: projectPath,
      encoding: 'utf8'
    }).trim();
    response += `*Branch:* ${branch}\n`;
  } catch (e) {}

  // Check if clean
  try {
    const status = execSync('git status --porcelain', {
      cwd: projectPath,
      encoding: 'utf8'
    }).trim();
    response += status ? '*Status:* Has uncommitted changes' : '*Status:* Clean';
  } catch (e) {}

  return { success: true, response };
}

/**
 * Process a natural language message
 * Returns: { response: string, action?: 'task'|'status'|'chat', project?: string, task?: string }
 */
async function processMessage(message) {
  // First, check for actionable commands
  const detected = detectAction(message);
  if (detected) {
    const result = await executeAction(detected.action, detected.params);
    // If action succeeded OR failed with a real error, return it
    // If notSentry flag is set, it means LLM determined this isn't a Sentry query - continue to normal processing
    if (!result.notSentry) {
      return result;
    }
  }

  // If no action detected (or LLM said not a Sentry query), try to identify if this is about a specific project
  const project = identifyProject(message);

  // Build context-aware prompt
  const systemPrompt = buildSystemPrompt();

  let projectContext = '';
  if (project) {
    projectContext = `\n\nContext for ${project.name}:\n${project.raw || 'No detailed context available.'}`;

    // Add current state info
    const projectPath = project.localPath || path.join(PROJECTS_DIR, project.name);
    if (fs.existsSync(projectPath)) {
      try {
        const packageJson = JSON.parse(fs.readFileSync(path.join(projectPath, 'package.json'), 'utf8'));
        projectContext += `\nCurrent version: ${packageJson.version || 'unknown'}`;
      } catch (e) { }

      try {
        const lastCommit = execSync('git log -1 --pretty=format:"%h %s (%ar)"', {
          cwd: projectPath,
          encoding: 'utf8'
        });
        projectContext += `\nLast commit: ${lastCommit}`;
      } catch (e) { }
    }
  }

  const fullPrompt = `${systemPrompt}${projectContext}

User message: ${message}

Respond helpfully and concisely.`;

  try {
    const response = await queryLLM(fullPrompt, {
      timeout: 120000,  // 2 minutes for complex queries
      workingDir: project ? (project.localPath || path.join(PROJECTS_DIR, project.name)) : '/root'
    });

    return {
      response,
      project: project?.name,
      success: true
    };
  } catch (error) {
    return {
      response: `LLM error: ${error.message}\n\nUse /help for available commands.`,
      success: false
    };
  }
}

/**
 * Run a task in a project (long-running, background)
 */
function runProjectTask(projectName, task, callback) {
  const projectPath = path.join(PROJECTS_DIR, projectName);

  if (!fs.existsSync(projectPath)) {
    callback({ success: false, error: `Project ${projectName} not found in ${PROJECTS_DIR}` });
    return null;
  }

  const timestamp = Date.now();
  const sessionName = `${projectName}-${timestamp}`;
  const logFile = `/root/logs/${sessionName}.log`;

  // Load project context for additional instructions
  loadContexts();
  const context = projectContexts[projectName];
  let contextInstructions = '';
  if (context) {
    contextInstructions = `Project context: ${context.description || ''}\nDeploy: ${context.deployPlatform || 'unknown'}`;
  }

  const fullTask = `${contextInstructions}\n\nTask: ${task}`;

  // Create execution script
  const scriptContent = `#!/bin/bash
set -a
source /root/doewah/.env
set +a

cd ${projectPath}
git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true

echo "========================================"
echo "Project: ${projectName}"
echo "Task: ${task}"
echo "Time: $(date)"
echo "========================================"

claude --dangerously-skip-permissions -p "${fullTask.replace(/"/g, '\\"')}" 2>&1 | tee -a ${logFile}

echo ""
echo "========================================"
echo "Task completed at $(date)"
echo "========================================"
`;

  const scriptPath = `/tmp/${sessionName}.sh`;
  fs.writeFileSync(scriptPath, scriptContent);
  fs.chmodSync(scriptPath, '755');

  // Run in tmux
  spawn('tmux', ['new-session', '-d', '-s', sessionName, scriptPath], {
    detached: true,
    stdio: 'ignore'
  });

  return { sessionName, logFile };
}

module.exports = {
  loadContexts,
  getAvailableProjects,
  identifyProject,
  detectAction,
  processMessage,
  runProjectTask,
  healthCheck,
  LLM_PROVIDER
};
