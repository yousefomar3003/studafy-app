import { z } from "zod";

/** GET /v1/classrooms — the teacher's class list. */
export const V1Classroom = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  grade: z.string(),
  section: z.string(),
  room: z.string().nullable(),
  student_count: z.number().int().min(0),
  weekly_sessions: z.number().int().min(0).nullable(),
  term_name: z.string().nullable(),
});
export type V1Classroom = z.infer<typeof V1Classroom>;

export const V1ClassroomListResponse = z.object({
  classrooms: z.array(V1Classroom),
});
export type V1ClassroomListResponse = z.infer<typeof V1ClassroomListResponse>;

export const V1ClassroomListError = z.object({
  error: z.object({
    code: z.enum(["UNAUTHORIZED", "FORBIDDEN", "NOT_FOUND", "INTERNAL_ERROR"]),
    message: z.string().min(1),
    request_id: z.string().min(1),
  }),
});
export type V1ClassroomListError = z.infer<typeof V1ClassroomListError>;
