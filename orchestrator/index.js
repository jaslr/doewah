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
const { execSync, spawn } = require('child_process');
const { queryLLM, healthCheck, LLM_PROVIDER } = require('./llm-adapter');

const CONTEXTS_DIR = '/root/doewah/contexts';
const PROJECTS_DIR = '/root/projects';

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
 * Process a natural language message
 * Returns: { response: string, action?: 'task'|'status'|'chat', project?: string, task?: string }
 */
async function processMessage(message) {
  // First, try to identify if this is about a specific project
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
      timeout: 30000,
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
  processMessage,
  runProjectTask,
  healthCheck,
  LLM_PROVIDER
};
