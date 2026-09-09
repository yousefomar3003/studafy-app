import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, json } from "../_shared/http.ts";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const auth = request.headers.get("Authorization") ?? "";
    const url = Deno.env.get("SUPABASE_URL")!;
    const client = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: auth } },
    });
    const service = createClient(
      url,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data: { user } } = await client.auth.getUser();
    if (!user) return json({ error: "Authentication required" }, 401);
    const body = await request.json();
    const { data: draft } = await service.from("ai_grading_drafts")
      .select(
        "id,status,grade_result_id,grade_results(id,assessment_id,assessments(classroom_id,classrooms(teacher_id,school_id)))",
      )
      .eq("id", body.draft_id).single();
    const grade = draft?.grade_results as Record<string, unknown> | undefined;
    const assessment = grade?.assessments as
      | Record<string, unknown>
      | undefined;
    const classroom = assessment?.classrooms as
      | Record<string, unknown>
      | undefined;
    if (
      !draft || classroom?.teacher_id !== user.id || draft.status !== "ready"
    ) return json({ error: "Review access required" }, 403);
    if (body.reviewer_id !== user.id) {
      return json({ error: "Reviewer identity mismatch" }, 403);
    }
    const scores = body.scores as Array<Record<string, unknown>>;
    if (!scores?.length) {
      return json({ error: "Every question must be reviewed" }, 422);
    }
    const { data: expected } = await service.from("assessment_questions")
      .select("id,maximum_score").eq("assessment_id", grade!.assessment_id);
    if (scores.length !== expected?.length) {
      return json({ error: "Every question must be reviewed" }, 422);
    }
    const originalRows = await service.from("question_suggestions")
      .select("question_id,proposed_score").eq("draft_id", draft.id);
    const original = new Map(
      (originalRows.data ?? []).map((
        row,
      ) => [row.question_id, Number(row.proposed_score)]),
    );
    let total = 0;
    for (const score of scores) {
      const question = expected!.find((item) => item.id === score.question_id);
      const value = Number(score.score);
      if (!question || value < 0 || value > Number(question.maximum_score)) {
        return json(
          { error: "A question score is outside its allowed range" },
          422,
        );
      }
      const changed = original.get(String(score.question_id)) !== value;
      if (changed && !String(score.reason ?? "").trim()) {
        return json({ error: "An override reason is required" }, 422);
      }
      await service.from("question_suggestions").update({
        teacher_score: value,
        override_reason: changed ? score.reason : null,
      })
        .eq("draft_id", draft.id).eq("question_id", score.question_id);
      total += value;
    }
    const reviewedAt = new Date().toISOString();
    await service.from("grade_results").update({
      score: total,
      state: "reviewed",
      reviewed_by: user.id,
      reviewed_at: reviewedAt,
    })
      .eq("id", grade!.id);
    await service.from("ai_grading_drafts").update({ status: "approved" }).eq(
      "id",
      draft.id,
    );
    await service.from("audit_events").insert({
      school_id: classroom.school_id,
      actor_id: user.id,
      action: "ai_grade_reviewed",
      entity_type: "grade_result",
      entity_id: grade!.id,
      before_value: { suggestions: Object.fromEntries(original) },
      after_value: { reviewed_scores: scores, total },
    });
    return json({ state: "reviewed", score: total, reviewed_at: reviewedAt });
  } catch (error) {
    return json({
      error: error instanceof Error ? error.message : "Unexpected error",
    }, 400);
  }
});
