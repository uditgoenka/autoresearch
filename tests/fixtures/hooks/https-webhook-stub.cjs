'use strict';

const fs = require('fs');
const https = require('https');
const { PassThrough, Writable } = require('stream');

process.env[['AR', 'NOTIFY', 'WEBHOOK'].join('_')] = 'https://127.0.0.1/notify';

https.request = (_options, onResponse) => {
  let body = '';
  const mode = process.argv[3] || 'success';
  const request = new Writable({
    write(chunk, _encoding, callback) {
      body += chunk;
      callback();
    }
  });
  request.setTimeout = (timeout, callback) => {
    if (mode === 'timeout') setTimeout(callback, Math.min(timeout, 10));
    return request;
  };
  request.destroy = () => request.emit('error', new Error('simulated timeout'));
  request.on('finish', () => {
    if (mode === 'error') {
      request.emit('error', new Error('simulated request error'));
      return;
    }
    if (mode === 'timeout') return;
    fs.writeFileSync(process.argv[2], body);
    const response = new PassThrough();
    onResponse(response);
    response.end();
  });
  return request;
};
