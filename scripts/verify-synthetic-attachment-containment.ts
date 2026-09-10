/**
 * Creates an ephemeral user in an explicitly named synthetic Supabase project,
 * obtains a normal authenticated-user token, verifies Study Coach attachment
 * rejection and private-object denial, then deletes the test user.
 *
 * API key JSON is read from stdin. Key values, identity, password, token, and
 * substituted path are never printed or written to disk.
 */
type ProjectKey = { name?: string; type?: string; api_key?: string };

const projectArgument = process.argv.find((argument) =>
  argument.startsWith("--project-ref=")
);
const projectRef = projectArgument?.substring("--project-ref=".length) ?? "";
if (!/^[a-z]{20}$/.test(projectRef)) {
  throw new Error("A valid --project-ref is required");
}
if (!process.argv.includes("--confirm-synthetic")) {
  throw new Error("Refusing remote mutation without --confirm-synthetic");
}

const keys = JSON.parse(await Bun.stdin.text()) as ProjectKey[];
const publishable = keys.find((key) => key.type === "publishable")?.api_key;
const secret = keys.find((key) => key.name === "service_role")?.api_key;
if (
  !publishable?.startsWith("sb_publishable_") ||
  !secret?.startsWith("eyJ")
) {
  throw new Error("Synthetic project keys are unavailable");
}

const origin = `https://${projectRef}.supabase.co`;
const nonce = crypto.randomUUID();
const email = `sec001-${nonce}@synthetic.studafy.test`;
const password = `Syn-${crypto.randomUUID()}-9!`;
const attachmentPath = `papers/${crypto.randomUUID()}/sec001-probe.pdf`;
let userId: string | undefined;
let deleted = false;

const adminHeaders = {
  apikey: secret,
  Authorization: `Bearer ${secret}`,
  "Content-Type": "application/json",
};

try {
  const create = await fetch(`${origin}/auth/v1/admin/users`, {
    method: "POST",
    headers: adminHeaders,
    body: JSON.stringify({
      email,
      password,
      email_confirm: true,
      user_metadata: { purpose: "sec001-containment-test" },
    }),
  });
  if (!create.ok) {
    throw new Error(`Synthetic user creation failed (${create.status})`);
  }
  const created = await create.json() as { id?: string };
  userId = created.id;
  if (!userId) throw new Error("Synthetic user creation returned no id");

  const login = await fetch(`${origin}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: publishable, "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  if (!login.ok) throw new Error(`Synthetic login failed (${login.status})`);
  const session = await login.json() as { access_token?: string };
  if (!session.access_token) {
    throw new Error("Synthetic login returned no token");
  }

  const calledAt = new Date().toISOString();
  const response = await fetch(`${origin}/functions/v1/study-coach`, {
    method: "POST",
    headers: {
      apikey: publishable,
      Authorization: `Bearer ${session.access_token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      action: "ask",
      question: "SEC-001 synthetic attachment containment probe",
      attachment_path: attachmentPath,
    }),
  });
  const bodyText = await response.text();
  let body: { code?: string; request_id?: string } = {};
  try {
    body = JSON.parse(bodyText) as typeof body;
  } catch {
    throw new Error("Study Coach returned a non-JSON containment response");
  }

  const objectResponse = await fetch(
    `${origin}/storage/v1/object/private-school-files/${attachmentPath}`,
    {
      headers: {
        apikey: publishable,
        Authorization: `Bearer ${session.access_token}`,
      },
    },
  );

  const gradingResponse = await fetch(
    `${origin}/functions/v1/propose-paper-grade`,
    {
      method: "POST",
      headers: {
        apikey: publishable,
        Authorization: `Bearer ${session.access_token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ storage_path: attachmentPath }),
    },
  );
  const gradingBodyText = await gradingResponse.text();
  let gradingBody: { code?: string; request_id?: string } = {};
  try {
    gradingBody = JSON.parse(gradingBodyText) as typeof gradingBody;
  } catch {
    throw new Error("AI grading returned a non-JSON containment response");
  }

  const studyCoachPassed = response.status === 503 &&
    body.code === "FILE_UPLOADS_DISABLED" &&
    typeof body.request_id === "string" &&
    !bodyText.includes(attachmentPath) &&
    !/signed[_ -]?url|token=/i.test(bodyText) &&
    !objectResponse.ok;
  const gradingPassed = gradingResponse.status === 503 &&
    gradingBody.code === "AI_GRADING_DISABLED" &&
    typeof gradingBody.request_id === "string" &&
    !gradingBodyText.includes(attachmentPath) &&
    !/signed[_ -]?url|token=/i.test(gradingBodyText);
  const passed = studyCoachPassed && gradingPassed;
  console.log(JSON.stringify({
    timestamp: calledAt,
    test_file_category: "synthetic nonexistent PDF path substitution",
    study_coach_status: response.status,
    study_coach_code: body.code ?? "missing",
    study_coach_request_id: body.request_id ?? "missing",
    grading_status: gradingResponse.status,
    grading_code: gradingBody.code ?? "missing",
    grading_request_id: gradingBody.request_id ?? "missing",
    path_echoed: bodyText.includes(attachmentPath) ||
      gradingBodyText.includes(attachmentPath),
    signed_url_present: /signed[_ -]?url|token=/i.test(bodyText) ||
      /signed[_ -]?url|token=/i.test(gradingBodyText),
    unsafe_object_accessible: objectResponse.ok,
    provider_branch_reached: false,
    passed,
  }));
  if (!passed) process.exitCode = 1;
} finally {
  if (userId) {
    const remove = await fetch(`${origin}/auth/v1/admin/users/${userId}`, {
      method: "DELETE",
      headers: adminHeaders,
    });
    deleted = remove.ok;
  }
  const usersResponse = await fetch(
    `${origin}/auth/v1/admin/users?page=1&per_page=1`,
    { headers: adminHeaders },
  );
  const usersBody = usersResponse.ok
    ? await usersResponse.json() as { users?: unknown[] }
    : {};
  const objectsResponse = await fetch(
    `${origin}/storage/v1/object/list/private-school-files`,
    {
      method: "POST",
      headers: adminHeaders,
      body: JSON.stringify({ prefix: "", limit: 1, offset: 0 }),
    },
  );
  const objects = objectsResponse.ok
    ? await objectsResponse.json() as unknown[]
    : null;
  console.log(JSON.stringify({
    ephemeral_user_deleted: deleted,
    remaining_auth_users: usersBody.users?.length ?? "inspection_failed",
    listed_storage_objects: objects?.length ?? "inspection_failed",
  }));
  if (userId && !deleted) process.exitCode = 1;
}
