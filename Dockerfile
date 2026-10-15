# Multi-stage Dockerfile for the Trivy CI gate demo.
#
# Build argument DEMO_SCENARIO selects the dependency set:
#   fixed      (default) -> lodash 4.18.1 from ./package.json + ./package-lock.json
#   vulnerable           -> lodash 4.17.20 from ./vulnerable/ (controlled demo ONLY)
#
# Examples:
#   docker build --build-arg DEMO_SCENARIO=fixed      -t trivy-demo:fixed .
#   docker build --build-arg DEMO_SCENARIO=vulnerable -t trivy-demo:vulnerable .

# ---------- Stage 1: dependency resolution ----------
FROM node:24-alpine AS deps

ARG DEMO_SCENARIO=fixed

WORKDIR /app

# Copy both manifest sets; only the selected set is promoted to the final package files.
COPY package.json package-lock.json ./
COPY vulnerable/package.json vulnerable/package-lock.json ./vulnerable/

# Validate the scenario and select the matching lockfile set. Unsupported values fail the build.
RUN case "$DEMO_SCENARIO" in \
      fixed) \
        echo "DEMO_SCENARIO=fixed: using remediated dependencies (lodash 4.18.1)" ;; \
      vulnerable) \
        echo "DEMO_SCENARIO=vulnerable: using DELIBERATELY VULNERABLE dependencies (lodash 4.17.20)" && \
        cp vulnerable/package.json package.json && \
        cp vulnerable/package-lock.json package-lock.json ;; \
      *) \
        echo "ERROR: unsupported DEMO_SCENARIO='$DEMO_SCENARIO'. Allowed values: fixed, vulnerable." >&2 && \
        exit 1 ;; \
    esac

# Install production dependencies only, exactly as recorded in the lockfile.
RUN npm ci --omit=dev --no-audit --no-fund && npm cache clean --force


# ---------- Stage 2: runtime ----------
FROM node:24-alpine AS runtime

ARG DEMO_SCENARIO=fixed
LABEL org.opencontainers.image.title="trivy-ci-gate-demo" \
      org.opencontainers.image.description="Node.js sample service for the Trivy DevSecOps gate demo" \
      demo.scenario="${DEMO_SCENARIO}"

ENV NODE_ENV=production \
    PORT=3000

WORKDIR /app

# The service only runs `node`, so the npm/npx/corepack tooling bundled in the base image is removed.
# This reduces the attack surface and removes unused third-party packages (e.g. npm's own bundled
# dependencies) from the runtime image. Node itself is unaffected.
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack \
           /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack

# Dedicated non-root system user and group for the runtime process.
RUN addgroup -S app && adduser -S -G app -h /app app

COPY --from=deps --chown=root:root /app/node_modules ./node_modules
COPY --from=deps /app/package.json ./package.json
COPY src ./src

USER app

EXPOSE 3000

# Health check uses Node itself (no extra tools needed in the Alpine image).
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["node", "-e", "require('http').get('http://127.0.0.1:' + (process.env.PORT || 3000) + '/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"]

CMD ["node", "src/app.js"]
