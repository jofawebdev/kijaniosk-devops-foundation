'use strict';

const fs = require('node:fs');
const path = require('node:path');

const outputDir = path.join(__dirname, '..', 'dist');
const sourceDir = path.join(__dirname, '..', 'src');

fs.rmSync(outputDir, { recursive: true, force: true });
fs.mkdirSync(outputDir, { recursive: true });

for (const file of ['payment.js', 'server.js']) {
  fs.copyFileSync(
    path.join(sourceDir, file),
    path.join(outputDir, file)
  );
}

console.log('Build completed: dist/payment.js and dist/server.js');
