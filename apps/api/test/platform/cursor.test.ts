import { describe, expect, test } from "bun:test";
import {
  filterHash,
  signCursor,
  verifyCursor,
} from "../../src/platform/cursor";

const KEY = "cursor-unit-test-key-with-more-than-32-bytes";
const SCHOOL = "bbbbbbbb-0000-4000-8000-000000000001";

describe("API-041 signed cursors", () => {
  test("bind operation, tenant, filters, and deterministic position", async () => {
    const filters = await filterHash({ classroomId: "class-a", pageSize: 50 });
    const cursor = await signCursor(KEY, {
      version: 1,
      filterVersion: 1,
      operation: "listAssignments",
      schoolId: SCHOOL,
      filterHash: filters,
      position: "aaaaaaaa-0000-4000-8000-000000000001",
    });
    expect(
      await verifyCursor(KEY, cursor, {
        operation: "listAssignments",
        schoolId: SCHOOL,
        filterHash: filters,
      }),
    ).toMatchObject({ position: "aaaaaaaa-0000-4000-8000-000000000001" });
    expect(
      await verifyCursor(KEY, cursor, {
        operation: "listGradeResults",
        schoolId: SCHOOL,
        filterHash: filters,
      }),
    ).toBeNull();
    expect(
      await verifyCursor(KEY, cursor, {
        operation: "listAssignments",
        schoolId: SCHOOL,
        filterHash: await filterHash({ classroomId: "class-b", pageSize: 50 }),
      }),
    ).toBeNull();
  });

  test("rejects tampering and malformed cursors", async () => {
    const filters = await filterHash({ pageSize: 50 });
    const cursor = await signCursor(KEY, {
      version: 1,
      operation: "listClassrooms",
      filterVersion: 1,
      schoolId: SCHOOL,
      filterHash: filters,
      position: "aaaaaaaa-0000-4000-8000-000000000001",
    });
    const replacement = cursor.endsWith("A") ? "B" : "A";
    expect(
      await verifyCursor(KEY, `${cursor.slice(0, -1)}${replacement}`, {
        operation: "listClassrooms",
        schoolId: SCHOOL,
        filterHash: filters,
      }),
    ).toBeNull();
    expect(
      await verifyCursor(KEY, "not-a-cursor", {
        operation: "listClassrooms",
        schoolId: SCHOOL,
        filterHash: filters,
      }),
    ).toBeNull();
  });
});
