import { z } from "zod";

/** GET /v1/classrooms — the teacher's class list. */
export const V1Classroom = z.strictObject({
  id: z.string().min(1),
  name: z.string().min(1),
  grade: z.string(),
  section: z.string(),
  room: z.string().nullable(),
  studentCount: z.number().int().min(0),
  weeklySessions: z.number().int().min(0).nullable(),
  termName: z.string().nullable(),
});
export type V1Classroom = z.infer<typeof V1Classroom>;

export const V1ClassroomListResponse = z.strictObject({
  classrooms: z.array(V1Classroom),
});
export type V1ClassroomListResponse = z.infer<typeof V1ClassroomListResponse>;

/** @deprecated All v1 failures use ProblemDetails. */
export const V1ClassroomListError = z.never();
export type V1ClassroomListError = z.infer<typeof V1ClassroomListError>;
