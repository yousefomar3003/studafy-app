/**
 * FILE-051 end-to-end verification against the local disposable stack:
 * upload → quarantine → scan/transform → publish → single-use re-authorized
 * delivery, plus rejection, school-scoped dedupe with physical cleanup, and
 * revocation after issue. Real Storage, real runtime roles, real workers.
 */
import {
  eicarPdf,
  hasBytes,
  IDS,
  jpegWithExif,
  openHarness,
} from "./file051-harness";
import { hasDrift, reconcile } from "./file051-reconciliation";

const h = await openHarness();
let ok = false;
try {
  // ---------------------------------------------------------------------
  // Upload, scan and transform
  // ---------------------------------------------------------------------
  const original = jpegWithExif("e2e");
  const lesson = await h.upload(
    IDS.teacher,
    original,
    "image/jpeg",
    "lesson.jpg",
  );
  const quarantined = await h.request(
    IDS.teacher,
    "GET",
    `/v1/files/${lesson.fileId}`,
  );
  h.record(
    "a completed upload is quarantined",
    "quarantined",
    (await quarantined.json() as { scanState: string }).scanState,
  );
  h.record(
    "a quarantined file cannot be published",
    409,
    (await h.request(
      IDS.teacher,
      "POST",
      `/v1/files/${lesson.fileId}/publish`,
      {
        audience: "students",
      },
    )).status,
  );

  await h.scanOnce();
  const scanned = await h.request(
    IDS.teacher,
    "GET",
    `/v1/files/${lesson.fileId}`,
  );
  h.record(
    "the scan worker marks a structurally valid image clean",
    "clean",
    (await scanned.json() as { scanState: string }).scanState,
  );
  const stored = await h.storage.openObject(
    "private-school-files",
    lesson.objectKey,
  );
  h.record(
    "the stored object no longer carries EXIF/GPS metadata",
    false,
    hasBytes(stored.bytes, "GPS"),
  );
  const row = (await h.admin<{ sha256: string; stored_sha256: string }[]>`
    select sha256, stored_sha256 from public.file_objects where id = ${lesson.fileId}
  `)[0]!;
  h.record(
    "the row keeps the upload digest and records a different stored digest",
    true,
    row.sha256 !== row.stored_sha256,
  );

  // ---------------------------------------------------------------------
  // Publication and delivery
  // ---------------------------------------------------------------------
  h.record(
    "an entitled student cannot download before publication",
    404,
    (await h.request(
      IDS.student,
      "POST",
      `/v1/files/${lesson.fileId}/download-intent`,
      {},
    ))
      .status,
  );
  const published = await h.request(
    IDS.teacher,
    "POST",
    `/v1/files/${lesson.fileId}/publish`,
    {
      audience: "students",
    },
  );
  h.record(
    "the assigned teacher publishes the clean file",
    201,
    published.status,
  );
  const publication = await published.json() as { resource: { id: string } };
  h.record(
    "publication stored no second object",
    1,
    Number(
      (await h.admin<{ count: string }[]>`
      select count(*) from public.file_objects where school_id = ${IDS.school}
    `)[0]!.count,
    ),
  );

  h.record(
    "an unenrolled student of the same school is refused a link",
    404,
    (await h.request(
      IDS.unenrolled,
      "POST",
      `/v1/files/${lesson.fileId}/download-intent`,
      {},
    ))
      .status,
  );
  h.record(
    "another school's teacher is refused a link",
    404,
    (await h.request(
      IDS.otherTeacher,
      "POST",
      `/v1/files/${lesson.fileId}/download-intent`,
      {},
    ))
      .status,
  );

  const intent = await h.request(
    IDS.student,
    "POST",
    `/v1/files/${lesson.fileId}/download-intent`,
    {},
  );
  h.record("the enrolled student receives a delivery link", 200, intent.status);
  const { downloadUrl } = await intent.json() as { downloadUrl: string };
  const path = new URL(downloadUrl);
  const deliveryPath = `${path.pathname}${path.search}`;

  h.record(
    "the link is useless to another account",
    404,
    (await h.request(IDS.unenrolled, "GET", deliveryPath)).status,
  );
  const delivered = await h.request(IDS.student, "GET", deliveryPath);
  h.record("the recipient downloads once", 200, delivered.status);
  const body = new Uint8Array(await delivered.arrayBuffer());
  h.record(
    "the delivered bytes are exactly the sanitized stored bytes",
    true,
    Buffer.compare(Buffer.from(body), Buffer.from(stored.bytes)) === 0,
  );
  h.record(
    "delivery is an attachment with nosniff and a sandbox policy",
    ["attachment", "nosniff", "sandbox; default-src 'none'"],
    [
      delivered.headers.get("content-disposition")?.split(";")[0],
      delivered.headers.get("x-content-type-options"),
      delivered.headers.get("content-security-policy"),
    ],
  );
  h.record(
    "the same link never works twice",
    404,
    (await h.request(IDS.student, "GET", deliveryPath)).status,
  );

  // Revocation between issue and use: the publication is withdrawn.
  const second = await h.request(
    IDS.student,
    "POST",
    `/v1/files/${lesson.fileId}/download-intent`,
    {},
  );
  const secondPath = new URL(
    (await second.json() as { downloadUrl: string }).downloadUrl,
  );
  await h.admin`
    update public.resource_publications rp set state = 'withdrawn', withdrawn_at = now()
    from public.resource_versions rv
    where rv.id = rp.resource_version_id and rv.resource_id = ${publication.resource.id}
  `;
  h.record(
    "a link issued before withdrawal is denied at use",
    404,
    (await h.request(
      IDS.student,
      "GET",
      `${secondPath.pathname}${secondPath.search}`,
    )).status,
  );
  h.record(
    "and no new link can be issued after withdrawal",
    404,
    (await h.request(
      IDS.student,
      "POST",
      `/v1/files/${lesson.fileId}/download-intent`,
      {},
    ))
      .status,
  );

  // ---------------------------------------------------------------------
  // Rejection never reaches users
  // ---------------------------------------------------------------------
  const malicious = await h.upload(
    IDS.teacher,
    eicarPdf(),
    "application/pdf",
    "worksheet.pdf",
  );
  await h.scanOnce();
  const rejected =
    await (await h.request(IDS.teacher, "GET", `/v1/files/${malicious.fileId}`))
      .json() as { scanState: string; failureCode: string };
  h.record(
    "the EICAR test file is rejected with a stable reason",
    ["rejected", "malware_detected"],
    [rejected.scanState, rejected.failureCode],
  );
  h.record(
    "a rejected file cannot be delivered, even to its owner",
    409,
    (await h.request(
      IDS.teacher,
      "POST",
      `/v1/files/${malicious.fileId}/download-intent`,
      {},
    ))
      .status,
  );
  h.record(
    "a rejected file cannot be published",
    409,
    (await h.request(
      IDS.teacher,
      "POST",
      `/v1/files/${malicious.fileId}/publish`,
      {
        audience: "students",
      },
    )).status,
  );
  await h.cleanupOnce();
  h.record(
    "the rejected object is physically deleted by exact key",
    false,
    (await h.storage.inspect("private-school-files", malicious.objectKey, 1024))
      .exists,
  );

  // ---------------------------------------------------------------------
  // School-scoped deduplication with physical cleanup
  // ---------------------------------------------------------------------
  const root = await h.upload(
    IDS.teacher,
    jpegWithExif("dedupe"),
    "image/jpeg",
    "a.jpg",
  );
  await h.scanOnce();
  const duplicate = await h.upload(
    IDS.teacher,
    jpegWithExif("dedupe"),
    "image/jpeg",
    "b.jpg",
  );
  await h.scanOnce();
  const dedup = (await h.admin<{ dedup_source_file_id: string | null }[]>`
    select dedup_source_file_id from public.file_objects where id = ${duplicate.fileId}
  `)[0]!;
  h.record(
    "the duplicate points at the same-school root",
    root.fileId,
    dedup.dedup_source_file_id,
  );
  await h.cleanupOnce();
  h.record(
    "the duplicate's redundant bytes are physically removed",
    false,
    (await h.storage.inspect("private-school-files", duplicate.objectKey, 1024))
      .exists,
  );
  h.record(
    "the root's bytes are untouched",
    true,
    (await h.storage.inspect("private-school-files", root.objectKey, 1024))
      .exists,
  );
  await h.request(
    IDS.teacher,
    "POST",
    `/v1/files/${duplicate.fileId}/publish`,
    {
      audience: "students",
    },
  );
  const dupIntent = await h.request(
    IDS.student,
    "POST",
    `/v1/files/${duplicate.fileId}/download-intent`,
    {},
  );
  const dupPath = new URL(
    (await dupIntent.json() as { downloadUrl: string }).downloadUrl,
  );
  const dupDelivered = await h.request(
    IDS.student,
    "GET",
    `${dupPath.pathname}${dupPath.search}`,
  );
  const rootBytes = await h.storage.openObject(
    "private-school-files",
    root.objectKey,
  );
  h.record(
    "the deduplicated file is delivered from the root's bytes",
    [200, true],
    [
      dupDelivered.status,
      Buffer.compare(
        Buffer.from(new Uint8Array(await dupDelivered.arrayBuffer())),
        Buffer.from(rootBytes.bytes),
      ) === 0,
    ],
  );

  const otherClassroom = crypto.randomUUID();
  await h.admin`
    insert into public.terms (id, school_id, name, starts_on, ends_on, active)
    values (${otherClassroom}::uuid, ${IDS.otherSchool}::uuid, 'Other', current_date - 1, current_date + 30, true)
  `;
  await h.admin`
    insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id)
    values (${otherClassroom}::uuid, ${IDS.otherSchool}::uuid, ${otherClassroom}::uuid, 'Other', 'G8', 'O', ${IDS.otherTeacher}::uuid)
  `;
  await h.admin`
    insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
    select ${IDS.otherSchool}::uuid, ${otherClassroom}::uuid, m.id, ${IDS.otherTeacher}::uuid, 'lead_teacher'
    from public.memberships m where m.school_id = ${IDS.otherSchool}::uuid and m.user_id = ${IDS.otherTeacher}::uuid
  `;
  const foreign = await h.upload(
    IDS.otherTeacher,
    jpegWithExif("dedupe"),
    "image/jpeg",
    "c.jpg",
    IDS.otherSchool,
    otherClassroom,
  );
  await h.scanOnce();
  const foreignStatus = await (await h.request(
    IDS.otherTeacher,
    "GET",
    `/v1/files/${foreign.fileId}`,
  ))
    .json() as Record<string, unknown>;
  const foreignRow = (await h.admin<{ dedup_source_file_id: string | null }[]>`
    select dedup_source_file_id from public.file_objects where id = ${foreign.fileId}
  `)[0]!;
  h.record(
    "identical bytes in another school are never deduplicated",
    [null, true],
    [
      foreignRow.dedup_source_file_id,
      (await h.storage.inspect("private-school-files", foreign.objectKey, 1024))
        .exists,
    ],
  );
  h.record(
    "the other school's status response carries no dedupe signal",
    [
      "createdAt",
      "declaredMediaType",
      "detectedMediaType",
      "displayName",
      "failureCode",
      "id",
      "purpose",
      "scanState",
      "scannedAt",
      "sizeBytes",
    ],
    Object.keys(foreignStatus).sort(),
  );

  // ---------------------------------------------------------------------
  // Storage reconciliation over everything above, then a planted orphan
  // ---------------------------------------------------------------------
  const settled = await reconcile(h.admin);
  h.record(
    "storage and rows reconcile with zero drift",
    false,
    hasDrift(settled),
  );
  const orphan = await h.storage.createUploadCapability(
    crypto.randomUUID(),
    "image/png",
  );
  await fetch(orphan.uploadUrl, {
    method: "PUT",
    headers: { "content-type": "image/png", "x-upsert": "false" },
    body: new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  });
  const drifted = await reconcile(h.admin);
  await h.storage.delete(orphan.bucket, orphan.objectKey);
  h.record(
    "reconciliation detects bytes with no session",
    1,
    drifted.orphan_objects,
  );

  ok = true;
} catch (error) {
  console.error("FAIL  verification aborted:", error);
} finally {
  const passed = await h.close();
  process.exit(ok && passed ? 0 : 1);
}
