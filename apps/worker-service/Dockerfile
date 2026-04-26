# =============================================================================
# Stage 1 — builder
# Installs dependencies from requirements.txt into an isolated prefix so only
# the runtime-needed site-packages are copied to the final stage.
# Even though requirements.txt is currently empty (stdlib-only), the builder
# stage is kept for consistency with the multi-stage pattern established in
# DA-04 and to make future dependency additions zero-friction.
# =============================================================================
FROM python:3.12 AS builder

WORKDIR /install

COPY requirements.txt .

# --prefix installs packages into /install so we can COPY just that directory
# to the final stage without dragging the full build image along.
# pip upgrade is pinned to a known-good invocation; no --no-cache-dir here
# because build layers are intentionally cached for faster rebuilds.
RUN pip install --upgrade pip \
    && pip install --prefix=/install -r requirements.txt

# =============================================================================
# Stage 2 — final (runtime)
# Minimal slim image: only Python runtime + application source.
# No build tools, no pip, no unnecessary packages.
# =============================================================================
FROM python:3.12-slim AS final

# Non-root user for security — principle of least privilege.
RUN groupadd --gid 1001 worker \
    && useradd --uid 1001 --gid 1001 --no-create-home --shell /bin/false worker

WORKDIR /app

# Copy installed site-packages from builder (currently empty, ready for future deps).
COPY --from=builder /install /usr/local

# Copy application source and manifest — nothing else.
COPY requirements.txt .
COPY src/ src/

# Switch to non-root before the process starts.
USER worker

# worker-service is a background process; it does not expose any port.
# HEARTBEAT_INTERVAL can be overridden at runtime (default handled in main.py).
ENV HEARTBEAT_INTERVAL=10

CMD ["python", "src/main.py"]
