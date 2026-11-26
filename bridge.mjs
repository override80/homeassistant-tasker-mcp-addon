// SPDX-License-Identifier: MIT
// Serves tasker-mcp (stdio-only upstream) as MCP streamable HTTP, with a bearer token, on one address.
// It reuses the package's own server/tool code, so tools, write allow list and snapshots behave exactly as over stdio.
import http from "node:http";
import { randomUUID, timingSafeEqual } from "node:crypto";
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";

const dir = process.env.TASKER_MCP_DIR;
const listen = process.env.BRIDGE_LISTEN || "127.0.0.1";
const port = Number(process.env.BRIDGE_PORT || 8765);
const access = process.env.BRIDGE_ACCESS_TOKEN || "";
if (!dir) throw new Error("TASKER_MCP_DIR is not set");
if (access.length < 16) throw new Error("access_token must be set (16+ characters)");

const req = createRequire(`${dir}/package.json`);
const load = (p) => import(pathToFileURL(req.resolve(p)).href);
const { loadConfig } = await load("./dist/config.js");
const { createServer } = await load("./dist/server.js");
const { createToolContext } = await load("./dist/tools/runtime.js");
const { taskToolRegistryFor } = await load("./dist/tools/tasktools.js");
const { StreamableHTTPServerTransport } = await load("@modelcontextprotocol/sdk/server/streamableHttp.js");
const { isInitializeRequest } = await load("@modelcontextprotocol/sdk/types.js");

const loaded = loadConfig([], process.env);
if (loaded.action === "help" || loaded.action === "version" || !loaded.config) {
  throw new Error("tasker-mcp configuration did not load");
}
const ctx = createToolContext(loaded.config);
const sessions = new Map(); // session id -> transport

function newServer() {
  const server = createServer(ctx);
  ctx.onToolsChanged(() => {
    const registry = taskToolRegistryFor(server);
    if (registry) registry.refresh().catch((e) => console.error("refresh_tools failed:", String(e)));
    else if (server.isConnected()) server.sendToolListChanged();
  });
  return server;
}

const okToken = (header) => {
  const m = /^Bearer (.+)$/.exec(header || "");
  if (!m) return false;
  const a = Buffer.from(m[1]);
  const b = Buffer.from(access);
  return a.length === b.length && timingSafeEqual(a, b);
};

const readBody = (r) =>
  new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    r.on("data", (c) => {
      size += c.length;
      if (size > 4_000_000) { reject(new Error("body too large")); r.destroy(); }
      else chunks.push(c);
    });
    r.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    r.on("error", reject);
  });

const send = (res, code, body) => {
  res.writeHead(code, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
};

const httpServer = http.createServer(async (rq, rs) => {
  try {
    const url = new URL(rq.url || "/", "http://x");
    if (url.pathname === "/health") { rs.writeHead(200); rs.end("ok"); return; }
    if (url.pathname !== "/mcp") { send(rs, 404, { error: "not found" }); return; }
    if (!okToken(rq.headers.authorization)) { send(rs, 401, { error: "unauthorized" }); return; }

    const sid = rq.headers["mcp-session-id"];
    let transport = typeof sid === "string" ? sessions.get(sid) : undefined;

    if (rq.method === "POST") {
      const text = await readBody(rq);
      let body;
      try { body = JSON.parse(text); } catch { send(rs, 400, { error: "invalid JSON" }); return; }
      if (!transport) {
        const first = Array.isArray(body) ? body[0] : body;
        if (sid || !isInitializeRequest(first)) {
          send(rs, 400, { jsonrpc: "2.0", error: { code: -32000, message: "No valid session id" }, id: null });
          return;
        }
        transport = new StreamableHTTPServerTransport({
          sessionIdGenerator: () => randomUUID(),
          onsessioninitialized: (id) => sessions.set(id, transport),
        });
        transport.onclose = () => { if (transport.sessionId) sessions.delete(transport.sessionId); };
        await newServer().connect(transport);
      }
      await transport.handleRequest(rq, rs, body);
      return;
    }
    if (rq.method === "GET" || rq.method === "DELETE") {
      if (!transport) { send(rs, 400, { error: "invalid or missing session id" }); return; }
      await transport.handleRequest(rq, rs);
      return;
    }
    send(rs, 405, { error: "method not allowed" });
  } catch (e) {
    console.error("request failed:", e);
    if (!rs.headersSent) send(rs, 500, { error: "internal error" });
  }
});

httpServer.listen(port, listen, () => console.log(`tasker-mcp bridge listening on ${listen}:${port} (${loaded.config.url ?? "adb forward"})`));
