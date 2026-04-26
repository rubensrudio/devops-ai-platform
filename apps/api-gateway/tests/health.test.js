'use strict';

const { describe, it, before, after, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');

// ---------------------------------------------------------------------------
// We require the app module WITHOUT binding a real port.
// The module guard (require.main === module) prevents the server from binding
// a real port during test runs.
// ---------------------------------------------------------------------------
let appModule;
let testServer;
let baseUrl;

before(() => {
  // Load module fresh
  appModule = require('../src/index');
  // Start an ephemeral server on a random port for integration-style tests
  testServer = http.createServer(appModule.app);
  return new Promise((resolve) => {
    testServer.listen(0, '127.0.0.1', () => {
      const { port } = testServer.address();
      baseUrl = `http://127.0.0.1:${port}`;
      resolve();
    });
  });
});

after(() => {
  return new Promise((resolve, reject) => {
    testServer.close((err) => (err ? reject(err) : resolve()));
  });
});

afterEach(() => {
  // Reset service state to 'ok' after each test to prevent state bleed
  appModule.setServiceState('ok');
});

/**
 * Helper: performs a GET request and returns { statusCode, headers, body }.
 */
function get(path) {
  return new Promise((resolve, reject) => {
    http.get(`${baseUrl}${path}`, (res) => {
      let raw = '';
      res.on('data', (chunk) => { raw += chunk; });
      res.on('end', () => {
        let body;
        try { body = JSON.parse(raw); } catch (_) { body = raw; }
        resolve({ statusCode: res.statusCode, headers: res.headers, body });
      });
    }).on('error', reject);
  });
}

// ---------------------------------------------------------------------------
// GET /health — healthy state
// ---------------------------------------------------------------------------
describe('GET /health — healthy state', () => {
  it('returns HTTP 200', async () => {
    const { statusCode } = await get('/health');
    assert.equal(statusCode, 200);
  });

  it('returns Content-Type application/json', async () => {
    const { headers } = await get('/health');
    assert.match(headers['content-type'], /application\/json/);
  });

  it('response body has status "ok"', async () => {
    const { body } = await get('/health');
    assert.equal(body.status, 'ok');
  });

  it('response body has service "api-gateway"', async () => {
    const { body } = await get('/health');
    assert.equal(body.service, 'api-gateway');
  });

  it('response body has a valid ISO 8601 timestamp', async () => {
    const before = Date.now();
    const { body } = await get('/health');
    const after = Date.now();

    const ts = new Date(body.timestamp).getTime();
    assert.ok(ts >= before, `timestamp ${body.timestamp} should be >= ${new Date(before).toISOString()}`);
    assert.ok(ts <= after, `timestamp ${body.timestamp} should be <= ${new Date(after).toISOString()}`);
  });

  it('response body contains exactly the three required keys', async () => {
    const { body } = await get('/health');
    assert.deepEqual(Object.keys(body).sort(), ['service', 'status', 'timestamp']);
  });
});

// ---------------------------------------------------------------------------
// GET /health — degraded state
// ---------------------------------------------------------------------------
describe('GET /health — degraded state', () => {
  it('returns HTTP 503', async () => {
    appModule.setServiceState('degraded');
    const { statusCode } = await get('/health');
    assert.equal(statusCode, 503);
  });

  it('response body has status "degraded"', async () => {
    appModule.setServiceState('degraded');
    const { body } = await get('/health');
    assert.equal(body.status, 'degraded');
  });

  it('response body still has service "api-gateway"', async () => {
    appModule.setServiceState('degraded');
    const { body } = await get('/health');
    assert.equal(body.service, 'api-gateway');
  });

  it('response body still has a valid ISO 8601 timestamp', async () => {
    appModule.setServiceState('degraded');
    const { body } = await get('/health');
    const ts = new Date(body.timestamp);
    assert.ok(!isNaN(ts.getTime()), `Expected a valid ISO timestamp, got: ${body.timestamp}`);
  });
});

// ---------------------------------------------------------------------------
// setServiceState — validation
// ---------------------------------------------------------------------------
describe('setServiceState — validation', () => {
  it('throws for invalid state value', () => {
    assert.throws(() => appModule.setServiceState('unknown'));
  });

  it('accepts "ok" without throwing', () => {
    assert.doesNotThrow(() => appModule.setServiceState('ok'));
  });

  it('accepts "degraded" without throwing', () => {
    assert.doesNotThrow(() => appModule.setServiceState('degraded'));
  });
});

// ---------------------------------------------------------------------------
// Unknown routes (404 guard)
// ---------------------------------------------------------------------------
describe('unknown routes', () => {
  it('GET /unknown returns 404', async () => {
    const { statusCode } = await get('/unknown');
    assert.equal(statusCode, 404);
  });
});
