# Deploying the API to AWS App Runner (eu-central-1)

## Why this exists

Measured from a laptop in Jordan against the Tokyo database:

| | |
|---|---|
| One database round trip | **291 ms** |
| Opening a connection (TLS + auth) | **2,334 ms** |
| One `BEGIN` / `SET LOCAL` / query / `COMMIT` | **1,137 ms** |

An authenticated read runs about two of those transactions and a write about
four, which is why reads took 2.5–3.5 s and creating a class took 4.6 s. None
of that is query cost — it is sixteen sequential trips across the planet.

Running the API in the same region as Postgres takes each round trip to about
a millisecond, so the same write costs roughly 20 ms and the user pays one
hop to the API instead of sixteen to Tokyo. **Co-location is the fix; nothing
in the code changes.**

App Runner over ECS Fargate: no VPC, subnets, load balancer or task
definitions to maintain, it takes an image straight from ECR, and it supplies
an IAM instance role — which is what lets CloudWatch logging work with no
access keys, exactly as `packages/infrastructure/src/cloudwatchLogs.ts`
assumes.

## Regions

Everything in **eu-central-1 (Frankfurt)**: the Supabase project, the ECR
repository, the App Runner service, the CloudWatch log group and the secrets.
A Jordan user is ~70 ms from Frankfurt against ~290 ms from Tokyo, and the
API is then ~1 ms from its database.

## 1. Prerequisites

- A Supabase project in **eu-central-1** (see `frankfurt-migration.md`).
- The new project's `DATABASE_URL`, `SUPABASE_URL`, service-role key, and a
  Redis instance in or near eu-central-1.
- `aws` CLI authenticated, and Docker able to build `linux/amd64`.

```bash
export AWS_REGION=eu-central-1
export ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
```

## 2. Secrets

Never in the image, never in a task definition, never in a dart-define.

```bash
aws secretsmanager create-secret --name studafy/api/production \
  --region "$AWS_REGION" \
  --secret-string '{
    "DATABASE_URL":"postgresql://...",
    "SUPABASE_URL":"https://<new-ref>.supabase.co",
    "SUPABASE_SERVICE_ROLE_KEY":"...",
    "API_CURSOR_SIGNING_KEY":"...",
    "RATE_LIMIT_HMAC_SIGNING_KEY":"...",
    "REDIS_URL":"redis://...",
    "TURNSTILE_SECRET":"..."
  }'
```

Rotate every value as you create it. The current ones have been on screen in
screenshots and in a VS Code backup file, so treat all of them as public.

## 3. Log group

The API creates its own stream but deliberately not the group, so the IAM
policy below needs no `logs:CreateLogGroup`.

```bash
aws logs create-log-group --log-group-name /studafy/application --region "$AWS_REGION"
aws logs put-retention-policy --log-group-name /studafy/application \
  --retention-in-days 30 --region "$AWS_REGION"
```

## 4. IAM

Two roles. The **access role** lets App Runner pull from ECR; the
**instance role** is what the running container is, and is the one the AWS
SDK resolves credentials from.

`instance-role-policy.json` — least privilege, scoped to the one log group:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "WriteOwnLogStreams",
      "Effect": "Allow",
      "Action": ["logs:CreateLogStream", "logs:PutLogEvents"],
      "Resource": "arn:aws:logs:eu-central-1:<ACCOUNT_ID>:log-group:/studafy/application:*"
    },
    {
      "Sid": "ReadOwnSecret",
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": "arn:aws:secretsmanager:eu-central-1:<ACCOUNT_ID>:secret:studafy/api/production-*"
    }
  ]
}
```

Deliberately **not** `AdministratorAccess`, and no `logs:CreateLogGroup`,
`logs:DeleteLogStream` or wildcard resource.

```bash
aws iam create-role --role-name StudafyApiInstanceRole \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"tasks.apprunner.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
aws iam put-role-policy --role-name StudafyApiInstanceRole \
  --policy-name StudafyApiRuntime --policy-document file://instance-role-policy.json

aws iam create-role --role-name StudafyApiAccessRole \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"build.apprunner.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
aws iam attach-role-policy --role-name StudafyApiAccessRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess
```

## 5. Build and push

App Runner runs **linux/amd64**. On an Apple Silicon Mac the default build is
arm64 and the service will fail to start, so the platform flag is required.

```bash
aws ecr create-repository --repository-name studafy-api --region "$AWS_REGION"
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

docker build --platform linux/amd64 -t studafy-api:latest .
docker tag studafy-api:latest "$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/studafy-api:latest"
docker push "$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/studafy-api:latest"
```

## 6. The service

`apprunner-service.json`:

```json
{
  "ServiceName": "studafy-api",
  "SourceConfiguration": {
    "AuthenticationConfiguration": {
      "AccessRoleArn": "arn:aws:iam::<ACCOUNT_ID>:role/StudafyApiAccessRole"
    },
    "AutoDeploymentsEnabled": false,
    "ImageRepository": {
      "ImageIdentifier": "<ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com/studafy-api:latest",
      "ImageRepositoryType": "ECR",
      "ImageConfiguration": {
        "Port": "8080",
        "RuntimeEnvironmentVariables": {
          "ENVIRONMENT": "production",
          "API_PORT": "8080",
          "LOG_LEVEL": "info",
          "AWS_LOG_GROUP": "/studafy/application",
          "PAY071_BILLING_ENABLED": "true",
          "TURNSTILE_ENABLED": "true"
        },
        "RuntimeEnvironmentSecrets": {
          "DATABASE_URL": "arn:aws:secretsmanager:eu-central-1:<ACCOUNT_ID>:secret:studafy/api/production:DATABASE_URL::",
          "SUPABASE_URL": "arn:aws:secretsmanager:eu-central-1:<ACCOUNT_ID>:secret:studafy/api/production:SUPABASE_URL::",
          "SUPABASE_SERVICE_ROLE_KEY": "arn:aws:secretsmanager:eu-central-1:<ACCOUNT_ID>:secret:studafy/api/production:SUPABASE_SERVICE_ROLE_KEY::",
          "API_CURSOR_SIGNING_KEY": "arn:aws:secretsmanager:eu-central-1:<ACCOUNT_ID>:secret:studafy/api/production:API_CURSOR_SIGNING_KEY::",
          "RATE_LIMIT_HMAC_SIGNING_KEY": "arn:aws:secretsmanager:eu-central-1:<ACCOUNT_ID>:secret:studafy/api/production:RATE_LIMIT_HMAC_SIGNING_KEY::",
          "REDIS_URL": "arn:aws:secretsmanager:eu-central-1:<ACCOUNT_ID>:secret:studafy/api/production:REDIS_URL::",
          "TURNSTILE_SECRET": "arn:aws:secretsmanager:eu-central-1:<ACCOUNT_ID>:secret:studafy/api/production:TURNSTILE_SECRET::"
        }
      }
    }
  },
  "InstanceConfiguration": {
    "Cpu": "1 vCPU",
    "Memory": "2 GB",
    "InstanceRoleArn": "arn:aws:iam::<ACCOUNT_ID>:role/StudafyApiInstanceRole"
  },
  "HealthCheckConfiguration": {
    "Protocol": "HTTP",
    "Path": "/healthz",
    "Interval": 10,
    "Timeout": 5,
    "HealthyThreshold": 1,
    "UnhealthyThreshold": 5
  }
}
```

`/healthz`, not `/readyz`: readiness also checks Redis and the database, and
a brief Redis blip should not make App Runner replace a container that is
serving fine. `readyz` stays the deploy-time and alarm check.

`AWS_REGION` is not set: App Runner provides it, and the SDK resolves
credentials from the instance role, so no access keys exist anywhere.

```bash
aws apprunner create-service --cli-input-json file://apprunner-service.json --region "$AWS_REGION"
```

## 7. Verify

```bash
URL="$(aws apprunner list-services --region "$AWS_REGION" \
  --query "ServiceSummaryList[?ServiceName=='studafy-api'].ServiceUrl" --output text)"

curl -s "https://$URL/readyz"          # {"ready":true,"reasons":[]}
curl -s -o /dev/null -w '%{time_total}\n' "https://$URL/healthz"
```

Then confirm the round trips actually collapsed — this is the whole point:

```bash
aws logs filter-log-events --log-group-name /studafy/application \
  --region "$AWS_REGION" --filter-pattern '{ $.event = "http_request_completed" }' \
  --query 'events[*].message' --output text | tail -20
```

`duration_ms` should be tens of milliseconds, not thousands. If it is still
in the thousands, the database is not in the same region as the service.

That log group is also what makes CloudWatch searchable by `request_id`,
which appears in every log line, in every `audit_events` row, and in the
RFC 7807 body the client receives.

## 8. Point the app at it

`config/dart-defines.production.json`: `STUDAFY_API_URL` becomes
`https://<service-url>`, and `SUPABASE_URL` the new project. Never put a
service-role key or any server secret in a dart-define — those files are
compiled into the app and are readable by anyone who downloads it.

## Still to do before real users

- Rotate every secret listed in step 2.
- A custom domain (`api.studafy.com`) on the App Runner service, so the app
  is not pinned to an AWS-generated hostname.
- CloudWatch alarms on `http_error` rate and on `readyz` failures.
- The worker (`apps/worker`) is not deployed here. It is a separate service
  and still uses the unredacted logger.
