const WebSocket = require("ws");
const ws = new WebSocket("ws://209.38.85.244:8405");
let chunks = [];

ws.on("open", () => {
  console.log("[1] Connected");
  ws.send(JSON.stringify({type: "auth", token: "dev-token"}));
});

ws.on("message", (data) => {
  const msg = JSON.parse(data.toString());

  if (msg.type === "stream.chunk" && msg.text) {
    chunks.push(msg.text);
    process.stdout.write(msg.text);
  } else if (msg.type !== "stream.chunk") {
    console.log("[" + msg.type + "]", msg.step || msg.error || "");
  }

  if (msg.type === "auth.success") {
    ws.send(JSON.stringify({type: "thread.create", projectHint: "test"}));
  }

  if (msg.type === "thread.created") {
    console.log("[2] Sending message...");
    ws.send(JSON.stringify({type: "thread.message", threadId: msg.id, content: "Say hello in exactly 3 words"}));
  }

  if (msg.type === "stream.end") {
    console.log("\n[SUCCESS]");
    ws.close();
    process.exit(0);
  }

  if (msg.type === "action.error") {
    ws.close();
    process.exit(1);
  }
});

ws.on("error", (err) => console.log("[ERROR]", err.message));
