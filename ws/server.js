const WebSocket = require('ws');
const { v4: uuidv4 } = require('uuid');
const orchestrator = require('../orchestrator');

const PORT = process.env.WS_PORT || 8080;

// Store active connections and threads
const connections = new Map();
const threads = new Map();

// Create WebSocket server
const wss = new WebSocket.Server({ port: PORT });

console.log(`WebSocket server listening on port ${PORT}`);

wss.on('connection', (ws) => {
  const connectionId = uuidv4();
  connections.set(connectionId, { ws, authenticated: false, userId: null });

  console.log(`New connection: ${connectionId}`);

  ws.on('message', async (data) => {
    try {
      const message = JSON.parse(data.toString());
      await handleMessage(connectionId, message);
    } catch (error) {
      console.error('Error handling message:', error);
      sendError(ws, null, error.message);
    }
  });

  ws.on('close', () => {
    console.log(`Connection closed: ${connectionId}`);
    connections.delete(connectionId);
  });

  ws.on('error', (error) => {
    console.error(`Connection error ${connectionId}:`, error);
  });
});

async function handleMessage(connectionId, message) {
  const conn = connections.get(connectionId);
  if (!conn) return;

  const { ws } = conn;
  const { type } = message;

  // Handle auth first
  if (type === 'auth') {
    await handleAuth(connectionId, message);
    return;
  }

  // Require auth for all other messages
  if (!conn.authenticated) {
    sendError(ws, null, 'Not authenticated');
    return;
  }

  switch (type) {
    case 'thread.create':
      handleThreadCreate(connectionId, message);
      break;
    case 'thread.message':
      await handleThreadMessage(connectionId, message);
      break;
    case 'thread.close':
      handleThreadClose(connectionId, message);
      break;
    case 'action.confirm':
      handleActionConfirm(connectionId, message);
      break;
    case 'action.cancel':
      handleActionCancel(connectionId, message);
      break;
    default:
      sendError(ws, null, `Unknown message type: ${type}`);
  }
}

async function handleAuth(connectionId, message) {
  const conn = connections.get(connectionId);
  if (!conn) return;

  const { token } = message;

  // TODO: Verify Google JWT token
  // For now, accept any token for development
  if (token) {
    conn.authenticated = true;
    conn.userId = 'dev-user';
    send(conn.ws, { type: 'auth.success', userId: conn.userId });
    console.log(`Authenticated: ${connectionId}`);
  } else {
    sendError(conn.ws, null, 'Invalid auth token');
  }
}

function handleThreadCreate(connectionId, message) {
  const conn = connections.get(connectionId);
  if (!conn) return;

  const threadId = uuidv4();
  const thread = {
    id: threadId,
    projectHint: message.projectHint || null,
    llmOverride: null,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    connectionId,
    messages: [],
    pendingActions: new Map(),
  };

  threads.set(threadId, thread);

  send(conn.ws, {
    type: 'thread.created',
    id: threadId,
    projectHint: thread.projectHint,
    createdAt: thread.createdAt,
    updatedAt: thread.updatedAt,
  });

  console.log(`Thread created: ${threadId} (project: ${thread.projectHint || 'general'})`);
}

async function handleThreadMessage(connectionId, message) {
  const conn = connections.get(connectionId);
  if (!conn) return;

  const { threadId, content, llm } = message;
  const thread = threads.get(threadId);

  if (!thread) {
    sendError(conn.ws, threadId, 'Thread not found');
    return;
  }

  // Update thread LLM if specified
  if (llm) {
    thread.llmOverride = llm;
  }

  // Store user message
  thread.messages.push({
    role: 'user',
    content,
    timestamp: new Date().toISOString(),
  });

  const actionId = uuidv4();

  // Send stream start
  send(conn.ws, {
    type: 'stream.start',
    threadId,
    actionId,
  });

  try {
    // Execute with orchestrator
    await orchestrator.executeWithStream(content, {
      threadId,
      projectHint: thread.projectHint,
      llm: thread.llmOverride,
      onChunk: (text) => {
        send(conn.ws, {
          type: 'stream.chunk',
          threadId,
          text,
        });
      },
      onStep: (step) => {
        send(conn.ws, {
          type: 'stream.step',
          threadId,
          step,
        });
      },
      onConfirm: (prompt) => {
        return new Promise((resolve) => {
          thread.pendingActions.set(actionId, { resolve, prompt });
          send(conn.ws, {
            type: 'action.confirm',
            threadId,
            actionId,
            prompt,
          });
        });
      },
      onComplete: (result) => {
        thread.messages.push({
          role: 'assistant',
          content: result,
          timestamp: new Date().toISOString(),
        });
        thread.updatedAt = new Date().toISOString();

        send(conn.ws, {
          type: 'stream.end',
          threadId,
        });

        send(conn.ws, {
          type: 'action.complete',
          threadId,
          actionId,
          result,
        });
      },
    });
  } catch (error) {
    console.error(`Error in thread ${threadId}:`, error);
    send(conn.ws, {
      type: 'action.error',
      threadId,
      actionId,
      error: error.message,
    });
    send(conn.ws, {
      type: 'stream.end',
      threadId,
    });
  }
}

function handleThreadClose(connectionId, message) {
  const conn = connections.get(connectionId);
  if (!conn) return;

  const { threadId } = message;

  if (threads.has(threadId)) {
    threads.delete(threadId);
    send(conn.ws, {
      type: 'thread.deleted',
      threadId,
    });
    console.log(`Thread closed: ${threadId}`);
  }
}

function handleActionConfirm(connectionId, message) {
  const { actionId, confirmed } = message;

  // Find thread with this pending action
  for (const [threadId, thread] of threads) {
    const pending = thread.pendingActions.get(actionId);
    if (pending) {
      pending.resolve(confirmed);
      thread.pendingActions.delete(actionId);
      return;
    }
  }
}

function handleActionCancel(connectionId, message) {
  const { actionId } = message;

  // Find thread with this pending action
  for (const [threadId, thread] of threads) {
    const pending = thread.pendingActions.get(actionId);
    if (pending) {
      pending.resolve(false);
      thread.pendingActions.delete(actionId);
      return;
    }
  }
}

function send(ws, message) {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(message));
  }
}

function sendError(ws, threadId, error) {
  send(ws, {
    type: 'error',
    threadId,
    error,
  });
}

// Broadcast to all authenticated connections
function broadcast(message, excludeConnectionId = null) {
  for (const [connId, conn] of connections) {
    if (conn.authenticated && connId !== excludeConnectionId) {
      send(conn.ws, message);
    }
  }
}

// Handle process termination
process.on('SIGINT', () => {
  console.log('Shutting down WebSocket server...');
  wss.close(() => {
    console.log('WebSocket server closed');
    process.exit(0);
  });
});

module.exports = { wss, broadcast };
