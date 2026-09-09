import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, json } from "../_shared/http.ts";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  const auth = request.headers.get("Authorization") ?? "";
  const url = Deno.env.get("SUPABASE_URL")!;
  const client = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: auth } },
  });
  const service = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: { user } } = await client.auth.getUser();
  if (!user) return json({ error: "Authentication required" }, 401);
  const body = await request.json();
  const { data: grade } = await service.from("grade_results")
    .select(
      "id,state,student_id,assessment_id,assessments(classroom_id,classrooms(teacher_id,school_id))",
    )
    .eq("id", body.grade_result_id).single();
  const assessment = grade?.assessments as Record<string, unknown> | undefined;
  const classroom = assessment?.classrooms as
    | Record<string, unknown>
    | undefined;
  if (!grade || classroom?.teacher_id !== user.id) {
    return json({ error: "Teacher access required" }, 403);
  }
  if (grade.state !== "reviewed") {
    return json(
      { error: "The result must be reviewed before publishing" },
      409,
    );
  }
  const publishedAt = new Date().toISOString();
  await service.from("grade_results").update({
    state: "published",
    published_at: publishedAt,
  }).eq("id", grade.id);
  const { data: student } = await service.from("students").select("user_id").eq(
    "id",
    grade.student_id,
  ).single();
  if (student?.user_id) {
    await service.from("notifications").insert({
      user_id: student.user_id,
      kind: "grade",
      title: "A new grade was published",
      body: "Open Grades to review the result.",
      route: `/grades/${grade.id}`,
      entity_id: grade.id,
    });
  }
  await service.from("audit_events").insert({
    school_id: classroom.school_id,
    actor_id: user.id,
    action: "grade_published",
    entity_type: "grade_result",
    entity_id: grade.id,
    before_value: { state: "reviewed" },
    after_value: { state: "published", published_at: publishedAt },
  });
  return json({ state: "published", published_at: publishedAt });
});
