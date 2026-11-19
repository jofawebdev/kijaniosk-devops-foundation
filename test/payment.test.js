'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { validatePayment } = require('../src/payment');

test('accepts a valid payment', () => {
  assert.deepEqual(
    validatePayment({ amountMinor: 1250, currency: 'KES' }),
    { amountMinor: 1250, currency: 'KES' }
  );
});

test('rejects zero or negative amounts', () => {
  assert.throws(
    () => validatePayment({ amountMinor: 0, currency: 'KES' }),
    RangeError
  );
});

test('rejects non-integer amounts', () => {
  assert.throws(
    () => validatePayment({ amountMinor: 12.5, currency: 'KES' }),
    RangeError
  );
});

test('rejects invalid currency codes', () => {
  assert.throws(
    () => validatePayment({ amountMinor: 100, currency: 'kes' }),
    TypeError
  );
});

test('rejects missing payment input', () => {
  assert.throws(() => validatePayment(null), TypeError);
});
