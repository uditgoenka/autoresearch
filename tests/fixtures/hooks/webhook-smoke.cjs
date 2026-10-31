'use strict';

const http = require('http');
const { spawn } = require('child_process');

const hook = process.argv[2];
if (!hook) process.exit(2);

const server = http.createServer((request, response) => {
  let body = '';
  request.setEncoding('utf8');
  request.on('data', (chunk) => { body += chunk; });
  request.on('end', () => {
    response.writeHead(204);
    response.end();
    const payload = JSON.parse(body);
    if (payload.text === 'autoresearch session completed') {
      process.stdout.write('webhook received\n');
      server.close();
    } else {
      process.exitCode = 1;
      server.close();
    }
  });
});

server.listen(0, '127.0.0.1', () => {
  const { port } = server.address();
  const key = ['AR', 'NOTIFY', 'WEBHOOK'].join('_');
  const child = spawn(process.execPath, [hook], {
    env: { ...process.env, [key]: `http://127.0.0.1:${port}/notify` },
    stdio: ['pipe', 'ignore', 'inherit']
  });
  child.stdin.end(JSON.stringify({ session_id: 'webhook-smoke' }));
  child.on('exit', (code) => {
    if (code !== 0) {
      process.exitCode = code || 1;
      server.close();
    }
  });
});

setTimeout(() => {
  process.exitCode = 1;
  server.close();
}, 3000).unref();
