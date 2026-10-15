'use strict';

/**
 * Unit and HTTP tests using only Node's built-in node:test runner.
 */
const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { buildGreeting, sanitizeName, DEFAULT_NAME, MAX_NAME_LENGTH } = require('../src/greet');
const { createServer } = require('../src/app');

describe('greeting logic', () => {
  it('returns a normal name unchanged', () => {
    assert.deepEqual(buildGreeting('Ada'), { name: 'Ada', message: 'Hello, Ada!' });
  });

  it('trims leading and trailing whitespace', () => {
    assert.equal(sanitizeName('   Ada   '), 'Ada');
    assert.equal(buildGreeting('\t Ada \n').message, 'Hello, Ada!');
  });

  it('collapses internal runs of whitespace to a single space', () => {
    assert.equal(sanitizeName('Ada     Lovelace'), 'Ada Lovelace');
    assert.equal(sanitizeName('Ada\t\tLovelace'), 'Ada Lovelace');
  });

  it('falls back to the default name for empty input', () => {
    assert.equal(buildGreeting('').name, DEFAULT_NAME);
  });

  it('falls back to the default name for whitespace-only input', () => {
    assert.equal(buildGreeting('     ').name, DEFAULT_NAME);
  });

  it('falls back to the default name when the value is missing or not a string', () => {
    assert.equal(buildGreeting(undefined).name, DEFAULT_NAME);
    assert.equal(buildGreeting(null).name, DEFAULT_NAME);
    assert.equal(buildGreeting(['Ada', 'Bob']).name, DEFAULT_NAME);
  });

  it('truncates overly long names to the maximum length', () => {
    const longName = 'x'.repeat(MAX_NAME_LENGTH + 50);
    assert.equal(sanitizeName(longName).length, MAX_NAME_LENGTH);
  });
});

describe('HTTP endpoints', () => {
  let server;
  let baseUrl;

  before(async () => {
    server = createServer();
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    const { port } = server.address();
    baseUrl = `http://127.0.0.1:${port}`;
  });

  after(async () => {
    await new Promise((resolve) => server.close(resolve));
  });

  it('GET / returns application information as JSON', async () => {
    const res = await fetch(`${baseUrl}/`);
    assert.equal(res.status, 200);
    assert.match(res.headers.get('content-type'), /^application\/json/);
    const body = await res.json();
    assert.equal(body.application, 'trivy-ci-gate-demo');
    assert.ok(Array.isArray(body.endpoints));
  });

  it('GET /health returns 200 with status ok', async () => {
    const res = await fetch(`${baseUrl}/health`);
    assert.equal(res.status, 200);
    assert.match(res.headers.get('content-type'), /^application\/json/);
    const body = await res.json();
    assert.equal(body.status, 'ok');
  });

  it('GET /greet sanitizes the supplied name', async () => {
    const res = await fetch(`${baseUrl}/greet?name=${encodeURIComponent('  Ada   Lovelace  ')}`);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.name, 'Ada Lovelace');
    assert.equal(body.message, 'Hello, Ada Lovelace!');
  });

  it('GET /greet without a name uses the default name', async () => {
    const res = await fetch(`${baseUrl}/greet`);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.name, DEFAULT_NAME);
  });

  it('unknown routes return 404 JSON', async () => {
    const res = await fetch(`${baseUrl}/does-not-exist`);
    assert.equal(res.status, 404);
    assert.match(res.headers.get('content-type'), /^application\/json/);
    const body = await res.json();
    assert.equal(body.error, 'Not Found');
  });

  it('non-GET methods return 405 JSON', async () => {
    const res = await fetch(`${baseUrl}/health`, { method: 'POST' });
    assert.equal(res.status, 405);
    const body = await res.json();
    assert.equal(body.error, 'Method Not Allowed');
  });
});
