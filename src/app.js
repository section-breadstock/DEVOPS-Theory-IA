'use strict';

/**
 * Minimal HTTP service built on node:http.
 * Routes: /, /health, /greet?name=..., and a JSON 404 for everything else.
 */
const http = require('node:http');
const pkg = require('../package.json');
const { buildGreeting } = require('./greet');

const PORT = Number(process.env.PORT) || 3000;

/**
 * Writes a JSON response with the correct content type.
 */
function sendJson(res, statusCode, body) {
  const payload = JSON.stringify(body);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(payload),
    'Cache-Control': 'no-store',
  });
  res.end(payload);
}

/**
 * Creates (but does not start) the HTTP server. Exported so tests can bind an ephemeral port.
 */
function createServer() {
  return http.createServer((req, res) => {
    if (req.method !== 'GET') {
      sendJson(res, 405, { error: 'Method Not Allowed', method: req.method });
      return;
    }

    const url = new URL(req.url, 'http://localhost');

    switch (url.pathname) {
      case '/':
        sendJson(res, 200, {
          application: pkg.name,
          version: pkg.version,
          description: pkg.description,
          endpoints: ['/', '/health', '/greet?name=Student'],
        });
        break;

      case '/health':
        sendJson(res, 200, {
          status: 'ok',
          uptimeSeconds: Math.round(process.uptime()),
        });
        break;

      case '/greet':
        sendJson(res, 200, buildGreeting(url.searchParams.get('name')));
        break;

      default:
        sendJson(res, 404, { error: 'Not Found', path: url.pathname });
    }
  });
}

// Only listen when executed directly (node src/app.js), not when required by tests.
if (require.main === module) {
  const server = createServer();
  server.listen(PORT, () => {
    console.log(`${pkg.name} v${pkg.version} listening on port ${PORT}`);
  });
}

module.exports = { createServer };
