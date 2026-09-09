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
  const { data: meeting } = await service.from("meetings")
    .select(
      "id,calendar_event_id,classroom_id,classrooms(teacher_id,school_id)",
    )
    .eq("id", body.meeting_id).single();
  const classroom = meeting?.classrooms as Record<string, unknown> | undefined;
  if (!meeting || classroom?.teacher_id !== user.id) {
    return json({ error: "Teacher access required" }, 403);
  }
  const brokerUrl = Deno.env.get("GOOGLE_TOKEN_BROKER_URL");
  const brokerSecret = Deno.env.get("GOOGLE_TOKEN_BROKER_SECRET");
  if (!brokerUrl || !brokerSecret) {
    return json({ error: "Google Workspace is not connected" }, 503);
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
  const response = await fetch(
    `https://www.googleapis.com/calendar/v3/calendars/primary/events/${
      encodeURIComponent(meeting.calendar_event_id)
    }?sendUpdates=all`,
    {
      method: "DELETE",
      headers: { "Authorization": `Bearer ${access_token}` },
    },
  );
  if (!response.ok && response.status !== 410) {
    return json(
      { error: "Google Calendar could not cancel this meeting" },
      502,
    );
  }
  await service.from("meetings").update({ state: "cancelled" }).eq(
    "id",
    meeting.id,
  );
  await service.from("meeting_deliveries").update({ state: "cancelled" }).eq(
    "meeting_id",
    meeting.id,
  );
  await service.from("audit_events").insert({
    school_id: classroom.school_id,
    actor_id: user.id,
    action: "meeting_cancelled",
    entity_type: "meeting",
    entity_id: meeting.id,
  });
  return json({ state: "cancelled" });
});
