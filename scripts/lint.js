'use strict';

const fs = require('node:fs');

const files = ['src/payment.js', 'test/payment.test.js'];
let failed = false;

for (const file of files) {
  const source = fs.readFileSync(file, 'utf8');

  if (!source.startsWith("'use strict';")) {
    console.error(`${file}: missing strict mode declaration`);
    failed = true;
  }

  if (/\b(debugger|eval)\s*\b/.test(source)) {
    console.error(`${file}: prohibited debugging or dynamic evaluation`);
    failed = true;
  }

  if (/\bTODO\b|\bFIXME\b/.test(source)) {
    console.error(`${file}: unresolved TODO/FIXME marker`);
    failed = true;
  }

  if (!source.endsWith('\n')) {
    console.error(`${file}: missing final newline`);
    failed = true;
  }
}

if (failed) {
  process.exitCode = 1;
} else {
  console.log(`Lint checks passed for ${files.length} files.`);
}
