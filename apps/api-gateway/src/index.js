'use strict';

const express = require('express');

// ---------------------------------------------------------------------------
// Environment validation
// ---------------------------------------------------------------------------
const API_PORT = parseInt(process.env.API_PORT || '3000', 10);

if (Number.isNaN(API_PORT) || API_PORT < 1 || API_PORT > 65535) {
  process.stderr.write(
    `[api-gateway] FATAL: API_PORT="${process.env.API_PORT}" is not a valid port number (1-65535).\n`
  );
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Service state
// ---------------------------------------------------------------------------
let serviceState = 'ok'; // can be set to 'degraded' at runtime

/**
 * Returns the current service state.
 * Exported so tests can inspect / mutate it via the module interface.
 */
function getServiceState() {
  return serviceState;
}

/**
 * Allows tests or future middleware to set the service state.
 * @param {'ok'|'degraded'} state
 */
function setServiceState(state) {
  if (state !== 'ok' && state !== 'degraded') {
    throw new Error(`Invalid service state: "${state}". Allowed values: "ok", "degraded".`);
  }
  serviceState = state;
}

// ---------------------------------------------------------------------------
// Express app
// ---------------------------------------------------------------------------
const app = express();

app.disable('x-powered-by');

/**
 * GET /health
 *
 * Returns HTTP 200 when the service is healthy, HTTP 503 when degraded.
 * Response body always follows the contract:
 *   { "status": "ok"|"degraded", "service": "api-gateway", "timestamp": "<ISO8601>" }
 */
app.get('/health', (req, res) => {
  const currentState = getServiceState();
  const body = {
    status: currentState,
    service: 'api-gateway',
    timestamp: new Date().toISOString(),
  };

  const httpStatus = currentState === 'ok' ? 200 : 503;
  res.status(httpStatus).json(body);
});

// ---------------------------------------------------------------------------
// Server bootstrap (only when this file is the entry-point, not when required
// by tests as a module)
// ---------------------------------------------------------------------------
let server;

if (require.main === module) {
  server = app.listen(API_PORT, () => {
    process.stdout.write(
      `[api-gateway] Server started — listening on port ${API_PORT} (state: ${getServiceState()})\n`
    );
  });
}

module.exports = { app, getServiceState, setServiceState, get server() { return server; } };
