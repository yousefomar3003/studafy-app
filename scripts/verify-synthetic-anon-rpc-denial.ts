/** Read-only remote proof that privileged helpers are not anon RPCs. */
type ProjectKey = { type?: string; api_key?: string };

const projectArgument = process.argv.find((argument) =>
  argument.startsWith("--project-ref=")
);
const projectRef = projectArgument?.substring("--project-ref=".length) ?? "";
if (!/^[a-z]{20}$/.test(projectRef)) {
  throw new Error("A valid --project-ref is required");
}

const keys = JSON.parse(await Bun.stdin.text()) as ProjectKey[];
const publishable = keys.find((key) => key.type === "publishable")?.api_key;
if (!publishable?.startsWith("sb_publishable_")) {
  throw new Error("The project did not return a public publishable key");
}

const zero = "00000000-0000-4000-8000-000000000000";
const probes: Record<string, Record<string, unknown>> = {
  is_school_member: { target_school: zero, allowed_roles: null },
  is_class_teacher: { target_classroom: zero },
  can_access_student: { target_student: zero },
  can_access_classroom: { target_classroom: zero },
  handle_new_auth_user: {},
  rls_auto_enable: {},
};

let passed = true;
for (const [name, body] of Object.entries(probes)) {
  const response = await fetch(
    `https://${projectRef}.supabase.co/rest/v1/rpc/${name}`,
    {
      method: "POST",
      headers: {
        apikey: publishable,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    },
  );
  const denied = response.status === 401 || response.status === 403 ||
    response.status === 404;
  console.log(
    JSON.stringify({ function: name, status: response.status, denied }),
  );
  passed = passed && denied;
}

console.log(JSON.stringify({ all_anonymous_rpc_probes_denied: passed }));
if (!passed) process.exitCode = 1;
