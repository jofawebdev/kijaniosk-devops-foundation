'use strict';

function validatePayment(payment) {
  if (!payment || typeof payment !== 'object') {
    throw new TypeError('Payment must be an object');
  }

  if (!Number.isSafeInteger(payment.amountMinor) ||
      payment.amountMinor <= 0) {
    throw new RangeError('Amount must be a positive integer in minor units');
  }

  if (typeof payment.currency !== 'string' ||
      !/^[A-Z]{3}$/.test(payment.currency)) {
    throw new TypeError('Currency must be a three-letter uppercase code');
  }

  return {
    amountMinor: payment.amountMinor,
    currency: payment.currency
  };
}

module.exports = { validatePayment };
