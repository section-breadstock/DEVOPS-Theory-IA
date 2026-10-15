'use strict';

/**
 * Greeting helpers. Kept free of HTTP concerns so they can be unit tested directly.
 * Lodash is used for the string sanitization.
 */
const _ = require('lodash');

const DEFAULT_NAME = 'World';
const MAX_NAME_LENGTH = 64;

/**
 * Sanitizes a user-supplied name:
 *  - non-string input becomes an empty string
 *  - leading/trailing whitespace is trimmed
 *  - internal runs of whitespace are collapsed to a single space
 *  - the result is truncated to MAX_NAME_LENGTH characters
 *
 * @param {unknown} rawName
 * @returns {string} sanitized name (may be empty)
 */
function sanitizeName(rawName) {
  if (typeof rawName !== 'string') {
    return '';
  }
  const collapsed = _.replace(_.trim(rawName), /\s+/g, ' ');
  return _.truncate(collapsed, { length: MAX_NAME_LENGTH, omission: '' });
}

/**
 * Builds the greeting payload. Falls back to DEFAULT_NAME when the sanitized name is empty.
 *
 * @param {unknown} rawName
 * @returns {{ name: string, message: string }}
 */
function buildGreeting(rawName) {
  const name = sanitizeName(rawName) || DEFAULT_NAME;
  return { name, message: `Hello, ${name}!` };
}

module.exports = { buildGreeting, sanitizeName, DEFAULT_NAME, MAX_NAME_LENGTH };
