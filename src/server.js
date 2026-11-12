'use strict';

const http = require('node:http');

const PORT = Number(process.env.PORT || 3001);
const VERSION = process.env.APP_VERSION || 'development';

const server = http.createServer((request, response) => {
  if (request.method === 'GET' && request.url === '/health') {
    response.writeHead(200, { 'Content-Type': 'application/json' });
    response.end(JSON.stringify({
      status: 'ok',
      service: 'kk-payments',
      version: VERSION
    }));
    return;
  }

  response.writeHead(404, { 'Content-Type': 'application/json' });
  response.end(JSON.stringify({ error: 'Not found' }));
});

server.listen(PORT, process.env.HOST || '0.0.0.0', () => {
  console.log(`kk-payments listening on port ${PORT}`);
});

function shutdown() {
  server.close(() => process.exit(0));
}

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
