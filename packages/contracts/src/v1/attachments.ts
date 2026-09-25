/**
 * Shared attachment vocabulary.
 *
 * Its own module because three unrelated surfaces need it - submissions,
 * messages and announcements - and `files.ts` already imports from
 * `academic.ts`. Defining it here keeps the import graph a tree: this file
 * imports nothing of ours, so nothing it touches can become a cycle.
 *
 * `files.ts` re-exports these, so existing importers do not have to change.
 */
import { z } from "zod";

const Id = z.string().uuid();

export const V1FileScanState = z.enum([
  "quarantined",
  "scanning",
  "clean",
  "rejected",
  "error",
  "deleted",
]);
export type V1FileScanState = z.infer<typeof V1FileScanState>;

/**
 * One attachment as it appears on the thing it is attached to.
 *
 * Deliberately smaller than `V1File`: a reader needs to render a row and know
 * whether it can be opened yet, and nothing else. There is no URL here and
 * there never will be - a download is a separate single-use grant bound to the
 * person asking for it.
 */
export const V1FileAttachment = z.strictObject({
  id: Id,
  displayName: z.string().min(1).max(255),
  sizeBytes: z.number().int().nonnegative(),
  mediaType: z.string().min(1).max(120).nullable(),
  /** Only `clean` can be downloaded; anything else is still in the pipeline. */
  scanState: V1FileScanState,
});
export type V1FileAttachment = z.infer<typeof V1FileAttachment>;

/**
 * The ids a caller attaches when it creates something.
 *
 * The server checks that each one is the caller's own unbound upload of the
 * matching purpose, so this list cannot be used to reach another person's
 * file or to re-target one that is already attached elsewhere.
 *
 * A function, not a constant, and deliberately so: the OpenAPI registry
 * registers every exported ZodType from the v1 barrel as a named component,
 * which would turn a bare array alias into a wire type of its own and make
 * the generated Dart a wrapper class instead of a `List<String>?`. Calling it
 * inlines the array at each use, which is what the wire actually carries.
 */
export const attachmentFileIds = () => z.array(Id).max(5).optional();
