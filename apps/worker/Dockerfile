# ARC-010 skeleton image. Security posture: pinned base, non-root user,
# frozen dependency install, no debug tooling or admin endpoints.
# Build from the repository root:
#   docker build -f apps/worker/Dockerfile -t studafy-worker .
FROM oven/bun:1.3.14-slim@sha256:d56a2534ffd262e92c12fd3249d3924d296d97086da773f821d7d0477435ea04

WORKDIR /app

# Manifest-first copy keeps the frozen install layer cacheable. Every
# workspace manifest is required: the frozen lockfile covers the whole graph.
COPY package.json bun.lock tsconfig.base.json ./
COPY apps/api/package.json apps/api/
COPY apps/worker/package.json apps/worker/
COPY packages/config/package.json packages/config/
COPY packages/contracts/package.json packages/contracts/
COPY packages/database/package.json packages/database/
COPY packages/domain/package.json packages/domain/
COPY packages/infrastructure/package.json packages/infrastructure/
COPY packages/observability/package.json packages/observability/
COPY packages/test-support/package.json packages/test-support/

RUN bun install --frozen-lockfile --production

COPY tsconfig.base.json ./
COPY packages packages
COPY apps/worker/src apps/worker/src
COPY apps/worker/package.json apps/worker/

USER bun

# The worker has no HTTP port; liveness is a Redis round-trip through the
# queue connection settings the process already holds.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["bun", "-e", "const { Redis } = await import('ioredis'); const client = new Redis(process.env.REDIS_URL, { maxRetriesPerRequest: 1, connectTimeout: 3000 }); await client.ping(); client.disconnect();"]

CMD ["bun", "run", "apps/worker/src/index.ts"]
