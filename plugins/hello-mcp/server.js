#!/usr/bin/env node
// hello-mcp: the smallest possible MCP server, for learning the protocol.
//
// MCP (Model Context Protocol) lets a client (like Claude Code) talk to a
// separate process that exposes "tools". This server talks over stdio:
// the client writes one JSON-RPC 2.0 request per line to our stdin, and we
// write one JSON-RPC 2.0 response per line to our stdout. No HTTP, no
// Content-Length headers (unlike LSP) -- just newline-delimited JSON.
//
// The handshake, in order:
//   1. client -> server: "initialize"            (request, has an id)
//   2. server -> client: result with our info
//   3. client -> server: "notifications/initialized" (notification, no id, no reply)
//   4. client -> server: "tools/list"             (request, has an id)
//   5. server -> client: result with our tool list
//   6. client -> server: "tools/call"             (request, has an id)
//   7. server -> client: result with the tool's output

const readline = require("node:readline");

const rl = readline.createInterface({ input: process.stdin, terminal: false });

// Send one JSON-RPC response line back to the client.
function respond(id, result) {
  const message = { jsonrpc: "2.0", id, result };
  process.stdout.write(JSON.stringify(message) + "\n");
}

// The one tool this server offers.
const HELLO_TOOL = {
  name: "hello",
  description: "Say hello to someone.",
  inputSchema: {
    type: "object",
    properties: {
      name: { type: "string", description: "Who to greet (optional)." },
    },
  },
};

rl.on("line", (line) => {
  if (!line.trim()) return; // ignore blank lines

  const message = JSON.parse(line);
  const { id, method, params } = message;

  if (method === "initialize") {
    respond(id, {
      protocolVersion: "2024-11-05",
      capabilities: { tools: {} },
      serverInfo: { name: "hello-mcp", version: "0.1.0" },
    });
  } else if (method === "notifications/initialized") {
    // A notification: no "id", so no response is expected. Just acknowledge
    // internally by doing nothing.
  } else if (method === "tools/list") {
    respond(id, { tools: [HELLO_TOOL] });
  } else if (method === "tools/call") {
    if (params.name === "hello") {
      const who = params.arguments?.name || "world";
      respond(id, {
        content: [{ type: "text", text: `Hello, ${who}!` }],
      });
    }
  }
});
