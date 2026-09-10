import { createClient } from "https://esm.sh/@supabase/supabase-js@2.116.0";
import { corsHeaders, json } from "../_shared/http.ts";
import { rejectFileAttachment } from "../_shared/containment.ts";

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
    if (!["ask", "quiz", "flashcards"].includes(body.action)) {
      return json({ error: "Unsupported action" }, 422);
    }
    const attachmentRejection = rejectFileAttachment(request, body);
    if (attachmentRejection) return attachmentRejection;
    const coachUrl = Deno.env.get("STUDY_COACH_URL");
    const coachKey = Deno.env.get("STUDY_COACH_KEY");
    if (!coachUrl || !coachKey) {
      return json({ error: "Study Coach is not configured" }, 503);
    }

    let materials: Array<Record<string, unknown>> = [];
    let studentId: string | null = null;
    if (body.classroom_id) {
      const { data: student } = await client.from("students").select("id").eq(
        "user_id",
        user.id,
      ).single();
      studentId = student?.id ?? null;
      const { data: enrollment } = await client.from("enrollments").select(
        "classroom_id",
      )
        .eq("classroom_id", body.classroom_id).eq("student_id", studentId).eq(
          "active",
          true,
        ).maybeSingle();
      if (!enrollment) {
        return json({ error: "You are not enrolled in this class" }, 403);
      }
      const { data } = await client.from("lesson_materials")
        .select(
          "title,body,media_type,lesson_sessions!inner(classroom_id,filed_at)",
        )
        .eq("lesson_sessions.classroom_id", body.classroom_id).not(
          "lesson_sessions.filed_at",
          "is",
          null,
        ).limit(30);
      materials = data ?? [];
    } else {
      const { data } = await client.from("lesson_materials")
        .select("title,body,media_type,lesson_sessions!inner(filed_at)")
        .not("lesson_sessions.filed_at", "is", null).limit(30);
      materials = data ?? [];
    }
    if (!materials.length) {
      return json(
        { error: "No authorized lesson material is available yet" },
        409,
      );
    }
    const aiResponse = await fetch(coachUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${coachKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        action: body.action,
        question: body.question,
        topic: body.topic,
        materials,
        constraints: { grounded_only: true, no_official_grade: true },
      }),
    });
    if (!aiResponse.ok) {
      return json({
        error: "Study Coach could not generate a grounded response",
      }, 502);
    }
    const result = await aiResponse.json();
    if (studentId && ["quiz", "flashcards"].includes(body.action)) {
      const count = body.action === "quiz"
        ? result.questions?.length
        : result.cards?.length;
      if (count) {
        await service.from("practice_sessions").insert({
          student_id: studentId,
          classroom_id: body.classroom_id,
          topic: body.topic,
          kind: body.action,
          item_count: count,
        });
      }
    }
    return json(result);
  } catch (error) {
    return json({
      error: error instanceof Error ? error.message : "Unexpected error",
    }, 400);
  }
});
