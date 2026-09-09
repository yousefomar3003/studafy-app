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
    const { data: classroom } = await client.from("classrooms")
      .select("id, school_id, teacher_id").eq("id", body.classroom_id).single();
    if (!classroom || classroom.teacher_id !== user.id) {
      return json({ error: "Teacher access required" }, 403);
    }

    const brokerUrl = Deno.env.get("GOOGLE_TOKEN_BROKER_URL");
    const brokerSecret = Deno.env.get("GOOGLE_TOKEN_BROKER_SECRET");
    if (!brokerUrl || !brokerSecret) {
      return json({
        error: "Google Workspace is not connected for this school",
      }, 503);
    }
    const brokerResponse = await fetch(brokerUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${brokerSecret}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        teacher_id: user.id,
        school_id: classroom.school_id,
      }),
    });
    if (!brokerResponse.ok) {
      return json({ error: "Google authorization must be renewed" }, 409);
    }
    const { access_token } = await brokerResponse.json();

    const studentIds = new Set<string>();
    const guardianIds = new Set<string>();
    const { data: enrollments } = await service.from("enrollments")
      .select("students(id,user_id)").eq("classroom_id", classroom.id).eq(
        "active",
        true,
      );
    for (const row of enrollments ?? []) {
      type RecipientStudent = { id: string; user_id: string | null };
      const relation = row.students as unknown as
        | RecipientStudent
        | RecipientStudent[]
        | null;
      const student = Array.isArray(relation) ? relation[0] : relation;
      if (!student) continue;
      if (student.user_id) studentIds.add(student.user_id);
      const { data: links } = await service.from("guardian_links")
        .select("guardian_id").eq("student_id", student.id).eq(
          "status",
          "verified",
        );
      for (const link of links ?? []) guardianIds.add(link.guardian_id);
    }
    const recipientIds = body.audience === "students"
      ? [...studentIds]
      : body.audience === "guardians"
      ? [...guardianIds]
      : [...new Set([...studentIds, ...guardianIds])];
    const attendees: Array<{ email: string }> = [];
    for (const id of recipientIds) {
      const { data } = await service.auth.admin.getUserById(id);
      if (data.user?.email) attendees.push({ email: data.user.email });
    }

    const calendarResponse = await fetch(
      "https://www.googleapis.com/calendar/v3/calendars/primary/events?conferenceDataVersion=1&sendUpdates=all",
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${access_token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          summary: body.title,
          start: { dateTime: body.starts_at },
          end: { dateTime: body.ends_at },
          attendees,
          conferenceData: {
            createRequest: {
              requestId: crypto.randomUUID(),
              conferenceSolutionKey: { type: "hangoutsMeet" },
            },
          },
        }),
      },
    );
    if (!calendarResponse.ok) {
      return json(
        { error: "Google Calendar could not create this meeting" },
        502,
      );
    }
    const event = await calendarResponse.json();
    const meetUrl = event.hangoutLink as string | undefined;
    if (!meetUrl) return json({ error: "Google returned no Meet link" }, 502);
    const { data: meeting, error } = await service.from("meetings").insert({
      classroom_id: classroom.id,
      title: body.title,
      starts_at: body.starts_at,
      ends_at: body.ends_at,
      audience: body.audience,
      calendar_event_id: event.id,
      meet_url: meetUrl,
      state: "scheduled",
      created_by: user.id,
    }).select("id").single();
    if (error) throw error;
    if (recipientIds.length) {
      await service.from("meeting_deliveries").insert(
        recipientIds.map((recipient_id) => ({
          meeting_id: meeting.id,
          recipient_id,
          state: "sent",
          delivered_at: new Date().toISOString(),
        })),
      );
    }
    await service.from("audit_events").insert({
      school_id: classroom.school_id,
      actor_id: user.id,
      action: "meeting_created",
      entity_type: "meeting",
      entity_id: meeting.id,
      after_value: {
        audience: body.audience,
        recipient_count: recipientIds.length,
      },
    });
    return json({
      meeting_id: meeting.id,
      meet_url: meetUrl,
      recipient_count: recipientIds.length,
    });
  } catch (error) {
    return json({
      error: error instanceof Error ? error.message : "Unexpected error",
    }, 400);
  }
});
