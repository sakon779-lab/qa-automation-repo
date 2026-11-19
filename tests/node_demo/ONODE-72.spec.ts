import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-72 — POST /passes/{id}/cancel
 *
 * Every row of test_designs/ONODE-72.csv becomes one test, titled with its CaseID.
 * API-only card: no browser, no screenshots. State is seeded through `db`, the call under
 * test goes through `api` (it carries this test's X-Request-Id), and every Post-Assertion
 * is read back from the database before the row's Teardown SQL runs.
 */

const PLATE = "กข 1234";
const REASON = "ขายรถแล้ว";

/** Seed one ACTIVE pass for this test's dynamicId (created_at = now()). */
async function seedActivePass(db: { exec(sql: string): Promise<void> }, id: number, status = "ACTIVE", createdAt = "now()") {
  await db.exec(
    `INSERT INTO passes (id, vehicle, months, plate, price, txn_id, status, created_at) ` +
      `VALUES (${id}, 'car', 1, '${PLATE}', 1500, 'txn-onode72-${id}', '${status}', ${createdAt})`,
  );
}

/** The row's Teardown SQL: children first, then the pass itself. */
async function teardown(db: { exec(sql: string): Promise<void> }, id: number) {
  await db.exec(
    `DELETE FROM pass_cancellations WHERE pass_id = ${id}; DELETE FROM passes WHERE id = ${id};`,
  );
}

test.describe("ONODE-72 — cancel a pass", () => {
  test("TC-001 cancels an ACTIVE pass with matching plate and returns 200 CANCELLED", async ({ api, db, dynamicId }) => {
    await seedActivePass(db, dynamicId);
    try {
      const res = await api.post(`/passes/${dynamicId}/cancel`, {
        data: { plate: PLATE, reason: REASON },
      });
      expect(res.status()).toBe(200);
      const body = await res.json();
      expect(body).toMatchObject({ id: dynamicId, status: "CANCELLED" });

      expect(await db.value(`SELECT status FROM passes WHERE id = ${dynamicId}`)).toBe("CANCELLED");
      expect(await db.value(`SELECT count(*) FROM pass_cancellations WHERE pass_id = ${dynamicId}`)).toBe(1);
      expect(await db.value(`SELECT reason FROM pass_cancellations WHERE pass_id = ${dynamicId}`)).toBe(REASON);
    } finally {
      await teardown(db, dynamicId);
    }
  });

  test("TC-002 trims plate and reason before comparison and storage", async ({ api, db, dynamicId }) => {
    await seedActivePass(db, dynamicId);
    try {
      const res = await api.post(`/passes/${dynamicId}/cancel`, {
        data: { plate: `  ${PLATE}  `, reason: "  ย้ายงาน  " },
      });
      expect(res.status()).toBe(200);
      const body = await res.json();
      expect(body).toMatchObject({ id: dynamicId, status: "CANCELLED" });

      expect(await db.value(`SELECT reason FROM pass_cancellations WHERE pass_id = ${dynamicId}`)).toBe("ย้ายงาน");
      expect(await db.value(`SELECT count(*) FROM pass_cancellations WHERE pass_id = ${dynamicId}`)).toBe(1);
    } finally {
      await teardown(db, dynamicId);
    }
  });

  test("TC-003 accepts a reason of exactly 200 characters after trim", async ({ api, db, dynamicId }) => {
    await seedActivePass(db, dynamicId);
    try {
      const reason = "ก".repeat(200);
      expect(reason.length).toBe(200);

      const res = await api.post(`/passes/${dynamicId}/cancel`, {
        data: { plate: PLATE, reason },
      });
      expect(res.status()).toBe(200);
      const body = await res.json();
      expect(body).toMatchObject({ id: dynamicId, status: "CANCELLED" });

      expect(await db.value(`SELECT length(reason) FROM pass_cancellations WHERE pass_id = ${dynamicId}`)).toBe(200);
      expect(await db.value(`SELECT status FROM passes WHERE id = ${dynamicId}`)).toBe("CANCELLED");
    } finally {
      await teardown(db, dynamicId);
    }
  });

  test("TC-004 rejects a reason of 201 characters with 400 reason is too long", async ({ api, db, dynamicId }) => {
    await seedActivePass(db, dynamicId);
    try {
      const reason = "ก".repeat(201);
      expect(reason.length).toBe(201);

      const res = await api.post(`/passes/${dynamicId}/cancel`, {
        data: { plate: PLATE, reason },
      });
      expect(res.status()).toBe(400);
      expect(await res.json()).toMatchObject({ detail: "reason is too long" });

      expect(await db.value(`SELECT status FROM passes WHERE id = ${dynamicId}`)).toBe("ACTIVE");
      expect(await db.value(`SELECT count(*) FROM pass_cancellations WHERE pass_id = ${dynamicId}`)).toBe(0);
    } finally {
      await teardown(db, dynamicId);
    }
  });

  test("TC-005 answers 404 pass not found when the id is not a positive integer ('abc')", async ({ api }) => {
    const res = await api.post(`/passes/abc/cancel`, {
      data: { plate: PLATE, reason: "x" },
    });
    expect(res.status()).toBe(404);
    expect(await res.json()).toMatchObject({ detail: "pass not found" });
  });

  test("TC-006 answers 404 pass not found when the id exceeds the Postgres integer range", async ({ api }) => {
    const res = await api.post(`/passes/2147483648/cancel`, {
      data: { plate: PLATE, reason: "x" },
    });
    expect(res.status()).toBe(404);
    expect(await res.json()).toMatchObject({ detail: "pass not found" });
  });

  test("TC-007 answers 404 pass not found when no passes row exists with that id", async ({ api, db, dynamicId }) => {
    // dynamicId is unique per test and never seeded here — no row can exist with it
    expect(await db.value(`SELECT count(*) FROM passes WHERE id = ${dynamicId}`)).toBe(0);

    const res = await api.post(`/passes/${dynamicId}/cancel`, {
      data: { plate: PLATE, reason: "x" },
    });
    expect(res.status()).toBe(404);
    expect(await res.json()).toMatchObject({ detail: "pass not found" });
  });

  test("TC-008 answers 400 plate is required when plate is missing from the body", async ({ api, db, dynamicId }) => {
    await seedActivePass(db, dynamicId);
    try {
      const res = await api.post(`/passes/${dynamicId}/cancel`, {
        data: { reason: REASON },
      });
      expect(res.status()).toBe(400);
      expect(await res.json()).toMatchObject({ detail: "plate is required" });

      expect(await db.value(`SELECT status FROM passes WHERE id = ${dynamicId}`)).toBe("ACTIVE");
    } finally {
      await teardown(db, dynamicId);
    }
  });

  test("TC-009 answers 400 reason is required when reason is whitespace-only after trim", async ({ api, db, dynamicId }) => {
    await seedActivePass(db, dynamicId);
    try {
      const res = await api.post(`/passes/${dynamicId}/cancel`, {
        data: { plate: PLATE, reason: "   " },
      });
      expect(res.status()).toBe(400);
      expect(await res.json()).toMatchObject({ detail: "reason is required" });

      expect(await db.value(`SELECT status FROM passes WHERE id = ${dynamicId}`)).toBe("ACTIVE");
      expect(await db.value(`SELECT count(*) FROM pass_cancellations WHERE pass_id = ${dynamicId}`)).toBe(0);
    } finally {
      await teardown(db, dynamicId);
    }
  });

  test("TC-010 answers 404 pass not found when the trimmed plate does not match, pass stays ACTIVE", async ({ api, db, dynamicId }) => {
    await seedActivePass(db, dynamicId);
    try {
      const res = await api.post(`/passes/${dynamicId}/cancel`, {
        data: { plate: "กข 9999", reason: "x" },
      });
      expect(res.status()).toBe(404);
      expect(await res.json()).toMatchObject({ detail: "pass not found" });

      expect(await db.value(`SELECT status FROM passes WHERE id = ${dynamicId}`)).toBe("ACTIVE");
      expect(await db.value(`SELECT count(*) FROM pass_cancellations WHERE pass_id = ${dynamicId}`)).toBe(0);
    } finally {
      await teardown(db, dynamicId);
    }
  });

  test("TC-011 answers 409 pass already cancelled and writes no second cancellation row", async ({ api, db, dynamicId }) => {
    await seedActivePass(db, dynamicId, "CANCELLED");
    await db.exec(
      `INSERT INTO pass_cancellations (pass_id, reason, cancelled_at) VALUES (${dynamicId}, '${REASON}', now())`,
    );
    try {
      const res = await api.post(`/passes/${dynamicId}/cancel`, {
        data: { plate: PLATE, reason: REASON },
      });
      expect(res.status()).toBe(409);
      expect(await res.json()).toMatchObject({ detail: "pass already cancelled" });

      expect(await db.value(`SELECT count(*) FROM pass_cancellations WHERE pass_id = ${dynamicId}`)).toBe(1);
      expect(await db.value(`SELECT status FROM passes WHERE id = ${dynamicId}`)).toBe("CANCELLED");
    } finally {
      await teardown(db, dynamicId);
    }
  });

  test("TC-012 answers 409 pass is not active when the stored status is REVOKED", async ({ api, db, dynamicId }) => {
    await seedActivePass(db, dynamicId, "REVOKED");
    try {
      const res = await api.post(`/passes/${dynamicId}/cancel`, {
        data: { plate: PLATE, reason: REASON },
      });
      expect(res.status()).toBe(409);
      expect(await res.json()).toMatchObject({ detail: "pass is not active" });

      expect(await db.value(`SELECT status FROM passes WHERE id = ${dynamicId}`)).toBe("REVOKED");
      expect(await db.value(`SELECT count(*) FROM pass_cancellations WHERE pass_id = ${dynamicId}`)).toBe(0);
    } finally {
      await teardown(db, dynamicId);
    }
  });

  test("TC-013 answers 409 pass is not active when the computed expires_at is in the past", async ({ api, db, dynamicId }) => {
    await seedActivePass(db, dynamicId, "ACTIVE", "now() - INTERVAL '2 months'");
    try {
      const res = await api.post(`/passes/${dynamicId}/cancel`, {
        data: { plate: PLATE, reason: REASON },
      });
      expect(res.status()).toBe(409);
      expect(await res.json()).toMatchObject({ detail: "pass is not active" });

      expect(await db.value(`SELECT status FROM passes WHERE id = ${dynamicId}`)).toBe("ACTIVE");
      expect(await db.value(`SELECT count(*) FROM pass_cancellations WHERE pass_id = ${dynamicId}`)).toBe(0);
    } finally {
      await teardown(db, dynamicId);
    }
  });

  test("TC-014 checks the id before the body: bad id answers 404 even with an invalid body", async ({ api }) => {
    const res = await api.post(`/passes/abc/cancel`, {
      data: { plate: "", reason: "" },
    });
    expect(res.status()).toBe(404);
    expect(await res.json()).toMatchObject({ detail: "pass not found" });
  });

  test("TC-015 GET of a cancelled pass answers CANCELLED and adds no cancelled_at or reason field", async ({ api, db, dynamicId }) => {
    await seedActivePass(db, dynamicId);
    try {
      const cancelRes = await api.post(`/passes/${dynamicId}/cancel`, {
        data: { plate: PLATE, reason: REASON },
      });
      expect(cancelRes.status()).toBe(200);
      expect(await cancelRes.json()).toMatchObject({ id: dynamicId, status: "CANCELLED" });

      const getRes = await api.get(`/passes/${dynamicId}`);
      expect(getRes.status()).toBe(200);
      const body = await getRes.json();
      expect(body).toMatchObject({ id: dynamicId, status: "CANCELLED" });
      expect(body).not.toHaveProperty("cancelled_at");
      expect(body).not.toHaveProperty("reason");

      expect(await db.value(`SELECT status FROM passes WHERE id = ${dynamicId}`)).toBe("CANCELLED");
    } finally {
      await teardown(db, dynamicId);
    }
  });

  test("TC-016 stores a SQL/XSS reason verbatim and never executes it", async ({ api, db, dynamicId }) => {
    await seedActivePass(db, dynamicId);
    try {
      const reason = "<script>alert(1)</script>";
      const res = await api.post(`/passes/${dynamicId}/cancel`, {
        data: { plate: PLATE, reason },
      });
      expect(res.status()).toBe(200);
      expect(await res.json()).toMatchObject({ id: dynamicId, status: "CANCELLED" });

      expect(await db.value(`SELECT reason FROM pass_cancellations WHERE pass_id = ${dynamicId}`)).toBe(reason);
      expect(await db.value(`SELECT count(*) FROM passes WHERE id = ${dynamicId}`)).toBe(1);
    } finally {
      await teardown(db, dynamicId);
    }
  });

  test("TC-017 two concurrent cancels yield exactly one 200 and one 409 pass already cancelled", async ({ api, db, dynamicId }) => {
    await seedActivePass(db, dynamicId);
    try {
      const payload = { data: { plate: PLATE, reason: REASON } };
      const [a, b] = await Promise.all([
        api.post(`/passes/${dynamicId}/cancel`, payload),
        api.post(`/passes/${dynamicId}/cancel`, payload),
      ]);

      const statuses = [a.status(), b.status()].sort((x, y) => x - y);
      expect(statuses).toEqual([200, 409]);

      const winner = a.status() === 200 ? a : b;
      const loser = a.status() === 200 ? b : a;
      expect(await winner.json()).toMatchObject({ id: dynamicId, status: "CANCELLED" });
      expect(await loser.json()).toMatchObject({ detail: "pass already cancelled" });

      expect(await db.value(`SELECT count(*) FROM pass_cancellations WHERE pass_id = ${dynamicId}`)).toBe(1);
      expect(await db.value(`SELECT status FROM passes WHERE id = ${dynamicId}`)).toBe("CANCELLED");
    } finally {
      await teardown(db, dynamicId);
    }
  });

  test("TC-018 answers 404 pass not found for a non-integer id ('7.0') without touching the database", async ({ api }) => {
    const res = await api.post(`/passes/7.0/cancel`, {
      data: { plate: PLATE, reason: "x" },
    });
    expect(res.status()).toBe(404);
    expect(await res.json()).toMatchObject({ detail: "pass not found" });
  });

  test("TC-019 answers 400 plate is required for a blank-after-trim plate, pass stays ACTIVE", async ({ api, db, dynamicId }) => {
    await seedActivePass(db, dynamicId);
    try {
      const res = await api.post(`/passes/${dynamicId}/cancel`, {
        data: { plate: "   ", reason: REASON },
      });
      expect(res.status()).toBe(400);
      expect(await res.json()).toMatchObject({ detail: "plate is required" });

      expect(await db.value(`SELECT status FROM passes WHERE id = ${dynamicId}`)).toBe("ACTIVE");
      expect(await db.value(`SELECT count(*) FROM pass_cancellations WHERE pass_id = ${dynamicId}`)).toBe(0);
    } finally {
      await teardown(db, dynamicId);
    }
  });

  test("TC-020 a successful cancel writes the status and exactly one cancellation row with the trimmed reason", async ({ api, db, dynamicId }) => {
    await seedActivePass(db, dynamicId);
    try {
      const res = await api.post(`/passes/${dynamicId}/cancel`, {
        data: { plate: PLATE, reason: REASON },
      });
      expect(res.status()).toBe(200);
      expect(await res.json()).toMatchObject({ id: dynamicId, status: "CANCELLED" });

      expect(await db.value(`SELECT status FROM passes WHERE id = ${dynamicId}`)).toBe("CANCELLED");
      expect(await db.value(`SELECT count(*) FROM pass_cancellations WHERE pass_id = ${dynamicId}`)).toBe(1);
      expect(await db.value(`SELECT reason FROM pass_cancellations WHERE pass_id = ${dynamicId}`)).toBe(REASON);
    } finally {
      await teardown(db, dynamicId);
    }
  });

  test("TC-021 ignores spoofed X-Forwarded-For / X-Real-IP and handles the cancel normally", async ({ api, db, dynamicId }) => {
    await seedActivePass(db, dynamicId);
    try {
      const res = await api.post(`/passes/${dynamicId}/cancel`, {
        data: { plate: PLATE, reason: REASON },
        headers: { "X-Forwarded-For": "203.0.113.7", "X-Real-IP": "203.0.113.7" },
      });
      expect(res.status()).toBe(200);
      expect(await res.json()).toMatchObject({ id: dynamicId, status: "CANCELLED" });

      expect(await db.value(`SELECT status FROM passes WHERE id = ${dynamicId}`)).toBe("CANCELLED");
      expect(await db.value(`SELECT count(*) FROM pass_cancellations WHERE pass_id = ${dynamicId}`)).toBe(1);
    } finally {
      await teardown(db, dynamicId);
    }
  });
});
