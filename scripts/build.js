'use strict';

const fs = require('node:fs');
const path = require('node:path');

const outputDir = path.join(__dirname, '..', 'dist');

fs.rmSync(outputDir, { recursive: true, force: true });
fs.mkdirSync(outputDir, { recursive: true });
fs.copyFileSync(
  path.join(__dirname, '..', 'src', 'payment.js'),
  path.join(outputDir, 'payment.js')
);

console.log('Build completed: dist/payment.js');
