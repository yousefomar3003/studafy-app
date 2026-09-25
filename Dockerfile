# Studafy API.
#
# Built to run in the same AWS region as Postgres. That co-location is the
# whole point: measured from a laptop in Jordan against the Tokyo database,
# one BEGIN/SET/query/COMMIT cost 1,137 ms because each of its four round
# trips cost 291 ms, and a single write makes several such transactions. In
# region those round trips are about a millisecond, which turns a 4.6 second
# write into roughly 20.
#
# Two stages so the runtime image carries no build tooling and no dev
# dependencies, and runs as a non-root user.

# --- build -----------------------------------------------------------------
FROM oven/bun:1.3.14-alpine AS build
WORKDIR /app

# Manifests first: this layer is cached until a dependency actually changes,
# which is the slowest step by far.
COPY package.json bun.lock ./
COPY apps/api/package.json apps/api/
COPY apps/worker/package.json apps/worker/
COPY packages/config/package.json packages/config/
COPY packages/contracts/package.json packages/contracts/
COPY packages/database/package.json packages/database/
COPY packages/domain/package.json packages/domain/
COPY packages/infrastructure/package.json packages/infrastructure/
COPY packages/observability/package.json packages/observability/
COPY packages/test-support/package.json packages/test-support/
# --production drops devDependencies: the API is run from TypeScript source by
# Bun, so test-support and the type-checker are never loaded at runtime and
# only make the image slower to pull.
RUN bun install --frozen-lockfile --production

COPY apps/ apps/
COPY packages/ packages/
COPY tsconfig.base.json ./

# --- runtime ---------------------------------------------------------------
FROM oven/bun:1.3.14-alpine AS runtime
WORKDIR /app

# Image-wide defaults. Everything secret - DATABASE_URL, the service-role key,
# the signing keys - is injected at runtime from Secrets Manager and must
# never appear in a layer.
ENV NODE_ENV=production \
    ENVIRONMENT=production \
    API_PORT=8080

COPY --from=build /app /app

# The base image ships a `bun` user; dropping to it means a container escape
# does not start as root.
USER bun

EXPOSE 8080

# App Runner health-checks the port itself, but an image-level check keeps
# `docker run` honest and matches what the platform probes.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD bun -e "fetch('http://127.0.0.1:8080/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

# Not `bun run start`: exec'ing bun directly makes it PID 1, so SIGTERM
# reaches the process and installGracefulShutdown gets its chance to drain
# in-flight requests and flush the last CloudWatch batch.
CMD ["bun", "apps/api/src/index.ts"]
