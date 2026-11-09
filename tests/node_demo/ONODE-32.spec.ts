import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-32 — GET /passes/{id} never returns a clear txn_id: the by-id read path masks the
 * stored value to a fixed '****' + its last 2 characters (B18), unconditionally (B20).
 *
 * One test per approved CSV row. The negative rows (TC-001/TC-002/TC-010) prove the id is
 * validated before any database query. The positive rows seed a pass through `db`, read it back
 * over HTTP, assert the masked body, and delete only the row they created in a `finally`
 * teardown so the fully-parallel suite never collides.
 *
 * TC-009 reads the reconciliation endpoint too: its contract (ONODE-29 B7/B15) is
 * `{ checked, suspicious: [{ plate, txn_id, reason }] }`, and a seeded pass with no successful
 * payment attempt is listed there with its txn_id masked — the same '****' + last 2 form the
 * by-id path must now return.
 *
 * AMENDED by ONODE-35 (TC-009): the GET /passes/{id} read now passes through the source-IP
 * per-client limiter and the process-wide global ceiling (client key = source IP only, X-API-Key
 * ignored). The app is built with an injected per-client limiter (max 30) and global limiter
 * (max 300) on a fixed clock, so this single read is not refused by a shared process-wide bucket
 * and the 200 body is unchanged — the masking assertions are untouched.
 *
 * AMENDED by ONODE-42 B1 (TC-009): GET /passes/reconciliation now requires the
 * `X-Reconciliation-Token` header equal to RECONCILIATION_TOKEN; without it the endpoint answers
 * 401. TC-009 therefore sends the token on its reconciliation call.
 *
 * AMENDED by ONODE-48 (TC-004/TC-007/TC-008/TC-009): the seed uses a per-row dynamic txn_id
 * ('txn_<dynamic_id>up' / 'txn_<dynamic_id>-1') so a run that dies before teardown cannot poison
 * later runs under the UNIQUE passes_txn_id index. TC-005/TC-006 keep their exact boundary values
 * ('abc' / 'ab') and therefore DELETE any leftover row with that txn_id before inserting.
 */
const RECONCILIATION_TOKEN = "qa-reconciliation-token";

test.describe("ONODE-32 — GET /passes/{id} masks txn_id", () => {
  test("TC-001 non-numeric id 'abc' → 404 'pass not found' (validated before any DB query)", async ({ api }) => {
    const res = await api.get("/passes/abc");
    expect(res.status()).toBe(404);
    expect(await res.json()).toEqual({ detail: "pass not found" });
  });

  test("TC-002 id one past Postgres integer max '2147483648' → 404 'pass not found' without querying the DB", async ({ api }) => {
    const res = await api.get("/passes/2147483648");
    expect(res.status()).toBe(404);
    expect(await res.json()).toEqual({ detail: "pass not found" });
  });

  test("TC-003 valid in-range integer with no passes row → 404 'pass not found'", async ({ api, dynamicId }) => {
    // A positive integer id that cannot exist: derived from the unique dynamicId, far above any
    // row this suite creates, and never inserted by this test.
    const missingId = 1_000_000_000 + dynamicId;
    const res = await api.get(`/passes/${missingId}`);
    expect(res.status()).toBe(404);
    expect(await res.json()).toEqual({ detail: "pass not found" });
  });

  test("TC-004 long stored txn_id 'txn_<dynamic_id>up' is masked to '****up'", async ({ api, db, dynamicId }) => {
    const txnId = `txn_${dynamicId}up`;
    await db.exec(
      `INSERT INTO passes (id, vehicle, months, plate, price, txn_id, status) ` +
        `VALUES (${dynamicId}, 'car', 3, 'ABC123', 4500, '${txnId}', 'ACTIVE')`,
    );
    try {
      const res = await api.get(`/passes/${dynamicId}`);
      expect(res.status()).toBe(200);
      const body = await res.json();
      expect(body).toEqual({
        id: dynamicId,
        vehicle: "car",
        months: 3,
        plate: "ABC123",
        price: 4500,
        currency: "THB",
        txn_id: "****up",
        status: "ACTIVE",
      });
      // The SEC-ONODE-29-1 replay value is never returned clear.
      expect(JSON.stringify(body)).not.toContain(txnId);

      expect(await db.value(`SELECT count(*) FROM passes WHERE id = ${dynamicId}`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE id = ${dynamicId};`);
    }
  });

  test("TC-005 3-char stored txn_id 'abc' is masked to '****bc'", async ({ api, db, dynamicId }) => {
    // The value must be EXACTLY 'abc' (masking length boundary): clear any leftover row from a
    // dead run before inserting, so the UNIQUE passes_txn_id index cannot reject the seed.
    await db.exec(`DELETE FROM passes WHERE txn_id = 'abc';`);
    await db.exec(
      `INSERT INTO passes (id, vehicle, months, plate, price, txn_id, status) ` +
        `VALUES (${dynamicId}, 'car', 1, 'ZZ7777', 500, 'abc', 'ACTIVE')`,
    );
    try {
      const res = await api.get(`/passes/${dynamicId}`);
      expect(res.status()).toBe(200);
      expect(await res.json()).toEqual({
        id: dynamicId,
        vehicle: "car",
        months: 1,
        plate: "ZZ7777",
        price: 500,
        currency: "THB",
        txn_id: "****bc",
        status: "ACTIVE",
      });

      expect(await db.value(`SELECT count(*) FROM passes WHERE id = ${dynamicId}`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE id = ${dynamicId};`);
    }
  });

  test("TC-006 2-char stored txn_id 'ab' is returned unchanged (length <= 2 is not masked)", async ({ api, db, dynamicId }) => {
    // The value must be EXACTLY 'ab' (masking length boundary): clear any leftover row from a
    // dead run before inserting, so the UNIQUE passes_txn_id index cannot reject the seed.
    await db.exec(`DELETE FROM passes WHERE txn_id = 'ab';`);
    await db.exec(
      `INSERT INTO passes (id, vehicle, months, plate, price, txn_id, status) ` +
        `VALUES (${dynamicId}, 'motorcycle', 2, 'MM999', 1200, 'ab', 'ACTIVE')`,
    );
    try {
      const res = await api.get(`/passes/${dynamicId}`);
      expect(res.status()).toBe(200);
      expect(await res.json()).toEqual({
        id: dynamicId,
        vehicle: "motorcycle",
        months: 2,
        plate: "MM999",
        price: 1200,
        currency: "THB",
        txn_id: "ab",
        status: "ACTIVE",
      });

      expect(await db.value(`SELECT count(*) FROM passes WHERE id = ${dynamicId}`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE id = ${dynamicId};`);
    }
  });

  test("TC-007 every non-txn_id field is unchanged while txn_id 'txn_<dynamic_id>-1' is masked to '****-1'", async ({ api, db, dynamicId }) => {
    const txnId = `txn_${dynamicId}-1`;
    await db.exec(
      `INSERT INTO passes (id, vehicle, months, plate, price, txn_id, status) ` +
        `VALUES (${dynamicId}, 'car', 3, 'ABC123', 4500, '${txnId}', 'ACTIVE')`,
    );
    try {
      const res = await api.get(`/passes/${dynamicId}`);
      expect(res.status()).toBe(200);
      const body = await res.json();
      expect(body).toEqual({
        id: dynamicId,
        vehicle: "car",
        months: 3,
        plate: "ABC123",
        price: 4500,
        currency: "THB",
        txn_id: "****-1",
        status: "ACTIVE",
      });
      expect(JSON.stringify(body)).not.toContain(txnId);

      expect(await db.value(`SELECT count(*) FROM passes WHERE id = ${dynamicId}`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE id = ${dynamicId};`);
    }
  });

  test("TC-008 the same pass read twice returns the SAME masked txn_id '****up' both times", async ({ api, db, dynamicId }) => {
    const txnId = `txn_${dynamicId}up`;
    await db.exec(
      `INSERT INTO passes (id, vehicle, months, plate, price, txn_id, status) ` +
        `VALUES (${dynamicId}, 'car', 3, 'ABC123', 4500, '${txnId}', 'ACTIVE')`,
    );
    try {
      const first = await api.get(`/passes/${dynamicId}`);
      expect(first.status()).toBe(200);
      const firstBody = await first.json();
      expect(firstBody).toMatchObject({ txn_id: "****up" });
      expect(JSON.stringify(firstBody)).not.toContain(txnId);

      const second = await api.get(`/passes/${dynamicId}`);
      expect(second.status()).toBe(200);
      const secondBody = await second.json();
      expect(secondBody).toMatchObject({ txn_id: "****up" });
      expect(JSON.stringify(secondBody)).not.toContain(txnId);

      expect(await db.value(`SELECT count(*) FROM passes WHERE id = ${dynamicId}`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE id = ${dynamicId};`);
    }
  });

  // AMENDED by ONODE-35: the by-id read now goes through the source-IP per-client limiter and the
  // process-wide global ceiling (client key = source IP only, X-API-Key ignored). The app is built
  // with an injected per-client limiter (max 30) and global limiter (max 300) on a fixed clock, so
  // this single read is not refused by a shared process-wide bucket; the 200 body is unchanged and
  // the masking assertions below are untouched.
  // AMENDED by ONODE-42 B1: the reconciliation call carries X-Reconciliation-Token.
  // AMENDED by ONODE-48: the seed uses a per-row dynamic txn_id ('txn_<dynamic_id>up').
  test("TC-009 GET /passes/reconciliation and GET /passes/{id} both return '****up', never the clear value", async ({ api, db, dynamicId }) => {
    const plate = `R${dynamicId}`.slice(0, 10);
    const txnId = `txn_${dynamicId}up`;
    await db.exec(
      `INSERT INTO passes (id, vehicle, months, plate, price, txn_id, status) ` +
        `VALUES (${dynamicId}, 'car', 3, '${plate}', 4500, '${txnId}', 'ACTIVE')`,
    );
    try {
      // Reconciliation lists a pass with no successful payment attempt under `suspicious`,
      // keyed by plate, with its txn_id masked (ONODE-29 B7/B15).
      const reconciliation = await api.get("/passes/reconciliation", {
        headers: { "X-Reconciliation-Token": RECONCILIATION_TOKEN },
      });
      expect(reconciliation.status()).toBe(200);
      const reconciliationBody = await reconciliation.json();
      const suspicious = (reconciliationBody.suspicious as Array<Record<string, unknown>>).filter(
        (entry) => entry.plate === plate,
      );
      expect(suspicious).toHaveLength(1);
      expect(suspicious[0]).toMatchObject({ plate, txn_id: "****up" });
      expect(suspicious[0].txn_id).not.toBe(txnId);

      // The by-id read is rate-limited by source IP (ONODE-35 B6) — a single read is admitted and
      // the masking contract is unchanged.
      const byId = await api.get(`/passes/${dynamicId}`);
      expect(byId.status()).toBe(200);
      const byIdBody = await byId.json();
      expect(byIdBody).toMatchObject({ txn_id: "****up" });
      expect(byIdBody.txn_id).not.toBe(txnId);

      expect(await db.value(`SELECT count(*) FROM passes WHERE id = ${dynamicId}`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE id = ${dynamicId};`);
    }
  });

  test("TC-010 id zero '0' → 404 'pass not found' (not a positive integer, validated without touching the DB)", async ({ api }) => {
    const res = await api.get("/passes/0");
    expect(res.status()).toBe(404);
    expect(await res.json()).toEqual({ detail: "pass not found" });
  });
});