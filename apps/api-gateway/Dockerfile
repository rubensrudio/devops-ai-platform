# =============================================================================
# Stage 1 — builder
# Purpose: install production-only dependencies using the full node:lts image
# that includes build tools (node-gyp, gcc) if any native modules are needed.
# =============================================================================
FROM node:lts AS builder

WORKDIR /app

# Copy only the manifest files first to leverage Docker layer cache.
# The dependency layer is rebuilt only when package*.json changes.
COPY package.json package-lock.json ./

# Install production dependencies only — no devDependencies.
# Using npm ci for reproducible, deterministic installs from the lockfile.
RUN npm ci --omit=dev

# =============================================================================
# Stage 2 — final
# Purpose: minimal runtime image containing only what is needed to run the app.
# node:lts-alpine is significantly smaller than node:lts (~50 MB vs ~350 MB).
# =============================================================================
FROM node:lts-alpine AS final

# Run as non-root user for security hardening.
# node:lts-alpine ships with a built-in "node" user (uid 1000).
USER node

WORKDIR /app

# Copy production node_modules from the builder stage.
COPY --from=builder --chown=node:node /app/node_modules ./node_modules

# Copy application source code.
COPY --chown=node:node src/ ./src/

# Declare the port the container listens on at runtime.
# The actual value is injected via the API_PORT environment variable.
# EXPOSE is documentation; the real binding is done by docker run / Compose.
ARG API_PORT=3000
ENV API_PORT=${API_PORT}
EXPOSE ${API_PORT}

# Health check so Docker / Compose knows when the container is ready.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:${API_PORT}/health || exit 1

# Start the application.
CMD ["node", "src/index.js"]
