# ARC-010 skeleton image. Security posture: pinned base, non-root user,
# frozen dependency install, no debug tooling or admin endpoints.
# Build from the repository root:
#   docker build -f apps/api/Dockerfile -t studafy-api .
FROM oven/bun:1.3.14-slim

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
COPY apps/api/src apps/api/src
COPY apps/api/package.json apps/api/

USER bun
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["bun", "-e", "await fetch('http://127.0.0.1:8080/healthz').then((r) => { if (!r.ok) process.exit(1); })"]

CMD ["bun", "run", "apps/api/src/index.ts"]
