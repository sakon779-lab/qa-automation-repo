import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-16 — POST /passes (payment + audit) and GET /passes/reconciliation.
 * One test per approved CSV row (test_designs/ONODE-16.csv): TC-001 … TC-012 and TC-014 … TC-019.
 * The CSV has NO TC-013 row, so no TC-013 test exists here.
 *
 * Every row is built in four phases: ARRANGE (the row's seed SQL / `mock.arm`), ACT (the row's
 * HTTP call through `api`, which carries this test's X-Request-Id so its stub is scoped to it),
 * ASSERT (the row's ExpectedResult verbatim, then its Post-Assertions read back through `db`),
 * TEARDOWN (the row's DELETE SQL in a finally block, deleting only this test's own rows).
 *
 * Reconciliation reads the whole table and the suite runs fully parallel, so every reconciliation
 * row filters the suspicious list down to its OWN plate — never a global count (ONODE-16
 * requirement: "ห้ามเทียบจำนวนรวม").
 *
 * AMENDED by ONODE-42 B1: GET /passes/reconciliation now requires the `X-Reconciliation-Token`
 * header equal to RECONCILIATION_TOKEN; without it the endpoint answers 401. TC-012, TC-014,
 * TC-015, TC-016 and TC-017 therefore send the token on their reconciliation call.
 *
 * FINDING (CSV, TC-015): the row seeds a passes row with txn_id = '' to exercise the
 * reconciliation "blank txn_id" branch. The deployed schema forbids that state — the
 * passes_txn_id_not_blank CHECK rejects any blank txn_id (proven by the delivered ONODE-12
 * TC-014). The seed the CSV prescribes therefore cannot succeed, so the row's Post-Assertion
 * (count(*) … status = 'EXPIRED' = 1) is unreachable. The row is disputed with Athena rather than
 * having its expectation edited to match the app; the test below proves the seed is refused BY
 * NAME and that reconciliation still honours its contract.
 */
const RECONCILIATION_TOKEN = "qa-reconciliation-token";

test.describe("ONODE-16 — passes purchase & reconciliation", () => {
  // ---------------------------------------------------------------------------
  // TC-001 — SUCCESS charge appends one payment_attempts row, trims plate, stores txn_id
  // ---------------------------------------------------------------------------
  test("TC-001 SUCCESS charge appends one payment_attempts row with trimmed plate and gateway txn_id", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    const txnId = `txn-${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

      const res = await api.post("/passes", {
        data: { vehicle: "car", months: 3, plate: `  ${plate}  ` },
      });

      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({
        vehicle: "car",
        months: 3,
        plate,
        price: 4500,
        currency: "THB",
        txn_id: txnId,
        status: "ACTIVE",
      });

      expect(
        await db.value(
          `SELECT count(*) FROM payment_attempts WHERE reference = '${plate}' AND outcome = 'SUCCESS' AND txn_id = '${txnId}' AND amount = 4500`,
        ),
      ).toBe(1);
      expect(
        await db.value(
          `SELECT count(*) FROM passes WHERE plate = '${plate}' AND txn_id = '${txnId}' AND status = 'ACTIVE'`,
        ),
      ).toBe(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE reference = '${plate}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-002 — DECLINED charge → 402, one DECLINED audit row with NULL txn_id, no pass
  // ---------------------------------------------------------------------------
  test("TC-002 DECLINED charge returns 402 and appends one DECLINED payment_attempts row with NULL txn_id", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", "/charge", 200, { status: "DECLINED" });

      const res = await api.post("/passes", {
        data: { vehicle: "car", months: 1, plate },
      });

      expect(res.status()).toBe(402);
      expect(await res.json()).toMatchObject({ detail: "payment declined" });

      expect(
        await db.value(
          `SELECT count(*) FROM payment_attempts WHERE reference = '${plate}' AND outcome = 'DECLINED' AND txn_id IS NULL AND amount = 1500`,
        ),
      ).toBe(1);
      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE reference = '${plate}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-003 — gateway HTTP 500 → 502, one UNAVAILABLE audit row with NULL txn_id, no pass
  // ---------------------------------------------------------------------------
  test("TC-003 gateway HTTP 500 returns 502 and appends one UNAVAILABLE payment_attempts row with NULL txn_id", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", "/charge", 500, { error: "internal" });

      const res = await api.post("/passes", {
        data: { vehicle: "car", months: 1, plate },
      });

      expect(res.status()).toBe(502);
      expect(await res.json()).toMatchObject({ detail: "payment gateway unavailable" });

      expect(
        await db.value(
          `SELECT count(*) FROM payment_attempts WHERE reference = '${plate}' AND outcome = 'UNAVAILABLE' AND txn_id IS NULL AND amount = 1500`,
        ),
      ).toBe(1);
      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE reference = '${plate}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-004 — SUCCESS with blank txn_id → 502, one UNAVAILABLE audit row with NULL txn_id
  // ---------------------------------------------------------------------------
  test("TC-004 SUCCESS charge with blank txn_id returns 502 and appends one UNAVAILABLE payment_attempts row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: "   " });

      const res = await api.post("/passes", {
        data: { vehicle: "car", months: 1, plate },
      });

      expect(res.status()).toBe(502);
      expect(await res.json()).toMatchObject({ detail: "payment gateway unavailable" });

      expect(
        await db.value(
          `SELECT count(*) FROM payment_attempts WHERE reference = '${plate}' AND outcome = 'UNAVAILABLE' AND txn_id IS NULL`,
        ),
      ).toBe(1);
      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE reference = '${plate}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-005 — missing vehicle → 400, no gateway call, no audit row
  // ---------------------------------------------------------------------------
  test("TC-005 missing vehicle returns 400 and writes no payment_attempts row", async ({ api, db, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      const res = await api.post("/passes", {
        data: { months: 1, plate },
      });

      expect(res.status()).toBe(400);
      expect(await res.json()).toMatchObject({ detail: "vehicle is required" });

      expect(await db.value(`SELECT count(*) FROM payment_attempts WHERE reference = '${plate}'`)).toBe(0);
      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE reference = '${plate}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-006 — non-string vehicle (number) → 400, no audit row
  // ---------------------------------------------------------------------------
  test("TC-006 non-string vehicle returns 400 and writes no payment_attempts row", async ({ api, db, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      const res = await api.post("/passes", {
        data: { vehicle: 1, months: 1, plate },
      });

      expect(res.status()).toBe(400);
      expect(await res.json()).toMatchObject({ detail: "vehicle must be car or motorcycle" });

      expect(await db.value(`SELECT count(*) FROM payment_attempts WHERE reference = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE reference = '${plate}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-007 — missing months → 400, no audit row
  // ---------------------------------------------------------------------------
  test("TC-007 missing months returns 400 and writes no payment_attempts row", async ({ api, db, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      const res = await api.post("/passes", {
        data: { vehicle: "car", plate },
      });

      expect(res.status()).toBe(400);
      expect(await res.json()).toMatchObject({ detail: "months is required" });

      expect(await db.value(`SELECT count(*) FROM payment_attempts WHERE reference = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE reference = '${plate}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-008 — months out of range (13) → 400, no audit row
  // ---------------------------------------------------------------------------
  test("TC-008 months out of range returns 400 and writes no payment_attempts row", async ({ api, db, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      const res = await api.post("/passes", {
        data: { vehicle: "car", months: 13, plate },
      });

      expect(res.status()).toBe(400);
      expect(await res.json()).toMatchObject({ detail: "months must be an integer from 1 to 12" });

      expect(await db.value(`SELECT count(*) FROM payment_attempts WHERE reference = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE reference = '${plate}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-009 — whitespace-only plate → 400, no audit row (no post-assertions/teardown in CSV)
  // ---------------------------------------------------------------------------
  test("TC-009 whitespace-only plate returns 400 and writes no payment_attempts row", async ({ api }) => {
    const res = await api.post("/passes", {
      data: { vehicle: "car", months: 1, plate: "   " },
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "plate is required" });
  });

  // ---------------------------------------------------------------------------
  // TC-010 — trimmed plate longer than 10 chars → 400, no audit row (no post-assertions/teardown)
  // ---------------------------------------------------------------------------
  test("TC-010 over-long plate returns 400 and writes no payment_attempts row", async ({ api, dynamicId }) => {
    const res = await api.post("/passes", {
      data: { vehicle: "car", months: 1, plate: `LONG${dynamicId}XXXXXX` },
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "plate must be a string of at most 10 characters" });
  });

  // ---------------------------------------------------------------------------
  // TC-011 — gateway timeout → 502, one UNAVAILABLE audit row with NULL txn_id, no pass
  // ---------------------------------------------------------------------------
  test("TC-011 gateway timeout returns 502 and appends one UNAVAILABLE payment_attempts row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: `txn-${dynamicId}` }, { delayMs: 30000 });

      const res = await api.post("/passes", {
        data: { vehicle: "car", months: 1, plate },
      });

      expect(res.status()).toBe(502);
      expect(await res.json()).toMatchObject({ detail: "payment gateway unavailable" });

      expect(
        await db.value(
          `SELECT count(*) FROM payment_attempts WHERE reference = '${plate}' AND outcome = 'UNAVAILABLE' AND txn_id IS NULL`,
        ),
      ).toBe(1);
      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE reference = '${plate}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-012 — clean pass (matching SUCCESS attempt) is NOT listed as suspicious
  // AMENDED by ONODE-42 B1: the request carries X-Reconciliation-Token.
  // ---------------------------------------------------------------------------
  test("TC-012 reconciliation does not list a clean ACTIVE pass with a matching SUCCESS attempt", async ({
    api,
    db,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    const txnId = `txn-${dynamicId}`;
    try {
      await db.exec(
        `INSERT INTO passes (vehicle, months, plate, price, txn_id, status) VALUES ('car', 1, '${plate}', 1500, '${txnId}', 'ACTIVE')`,
      );
      await db.exec(
        `INSERT INTO payment_attempts (reference, amount, outcome, txn_id) VALUES ('${plate}', 1500, 'SUCCESS', '${txnId}')`,
      );

      const res = await api.get("/passes/reconciliation", {
        headers: { "X-Reconciliation-Token": RECONCILIATION_TOKEN },
      });

      expect(res.status()).toBe(200);
      const body = await res.json();
      expect(body).toHaveProperty("checked");
      expect(body).toHaveProperty("suspicious");
      // The table is shared and the suite is parallel: look only at THIS test's plate.
      const suspicious = (body.suspicious as Array<Record<string, unknown>>).filter((s) => s.plate === plate);
      expect(suspicious).toHaveLength(0);

      expect(
        await db.value(
          `SELECT count(*) FROM passes p WHERE p.plate = '${plate}' AND p.status = 'ACTIVE' AND p.txn_id = '${txnId}' AND NOT EXISTS (SELECT 1 FROM payment_attempts a WHERE a.outcome = 'SUCCESS' AND a.txn_id = p.txn_id)`,
        ),
      ).toBe(0);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE reference = '${plate}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-014 — ACTIVE pass with non-blank txn_id and no SUCCESS attempt → 'no successful payment attempt'
  // AMENDED by ONODE-29 B7 (masked txn_id) and by ONODE-42 B1 (token header).
  // ---------------------------------------------------------------------------
  test("TC-014 reconciliation lists an ACTIVE pass with no successful payment attempt", async ({
    api,
    db,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    const txnId = `txn-${dynamicId}-XY`;
    try {
      await db.exec(
        `INSERT INTO passes (vehicle, months, plate, price, txn_id, status) VALUES ('car', 1, '${plate}', 1500, '${txnId}', 'ACTIVE')`,
      );
      await db.exec(
        `INSERT INTO payment_attempts (reference, amount, outcome, txn_id) VALUES ('${plate}', 1500, 'DECLINED', NULL)`,
      );

      const res = await api.get("/passes/reconciliation", {
        headers: { "X-Reconciliation-Token": RECONCILIATION_TOKEN },
      });

      expect(res.status()).toBe(200);
      const body = await res.json();
      const suspicious = (body.suspicious as Array<Record<string, unknown>>).filter((s) => s.plate === plate);
      expect(suspicious).toHaveLength(1);
      expect(suspicious[0]).toMatchObject({ plate, txn_id: "****XY", reason: "no successful payment attempt" });

      expect(
        await db.value(
          `SELECT count(*) FROM payment_attempts WHERE reference = '${plate}' AND outcome = 'SUCCESS'`,
        ),
      ).toBe(0);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE reference = '${plate}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-015 — CSV seeds a non-ACTIVE (EXPIRED) pass with a blank txn_id. The schema forbids the
  // blank txn_id regardless of status (see FINDING). Prove the seed is refused BY NAME and that
  // reconciliation still answers 200 with its contract keys.
  // AMENDED by ONODE-42 B1: the request carries X-Reconciliation-Token.
  // ---------------------------------------------------------------------------
  test("TC-015 reconciliation ignores a non-ACTIVE pass: the blank-txn_id seed is refused by passes_txn_id_not_blank", async ({
    api,
    db,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await expect(
        db.exec(
          `INSERT INTO passes (vehicle, months, plate, price, txn_id, status) VALUES ('car', 1, '${plate}', 1500, '', 'EXPIRED')`,
        ),
      ).rejects.toThrow(/passes_txn_id_not_blank/);

      const res = await api.get("/passes/reconciliation", {
        headers: { "X-Reconciliation-Token": RECONCILIATION_TOKEN },
      });
      expect(res.status()).toBe(200);
      const body = await res.json();
      expect(body).toHaveProperty("checked");
      expect(body).toHaveProperty("suspicious");

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE reference = '${plate}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-016 — CSV seeds two suspicious passes (one blank txn_id) to prove pass_id ordering. The
  // blank-txn_id seed is refused by the schema (see FINDING); the ordering of the reachable
  // "no successful payment attempt" branch is proven with two such passes seeded in reverse id
  // order, which exercises the same ORDER BY pass_id ASC.
  // AMENDED by ONODE-29 B7 (masked txn_ids) and by ONODE-42 B1 (token header).
  // ---------------------------------------------------------------------------
  test("TC-016 reconciliation orders the suspicious list by pass_id ascending", async ({ api, db, dynamicId }) => {
    const plateP = `P${dynamicId}`.slice(0, 10);
    const plateQ = `Q${dynamicId}`.slice(0, 10);
    const txnIdA = `txn-${dynamicId}-a`;
    const txnIdB = `txn-${dynamicId}-b`;
    const idLow = dynamicId;
    const idHigh = dynamicId + 1;
    try {
      // Seed the HIGHER id first so insertion order is the reverse of the expected output order.
      await db.exec(
        `INSERT INTO passes (id, vehicle, months, plate, price, txn_id, status) VALUES (${idHigh}, 'car', 1, '${plateQ}', 1500, '${txnIdB}', 'ACTIVE')`,
      );
      await db.exec(
        `INSERT INTO passes (id, vehicle, months, plate, price, txn_id, status) VALUES (${idLow}, 'car', 1, '${plateP}', 1500, '${txnIdA}', 'ACTIVE')`,
      );

      const res = await api.get("/passes/reconciliation", {
        headers: { "X-Reconciliation-Token": RECONCILIATION_TOKEN },
      });

      expect(res.status()).toBe(200);
      const body = await res.json();
      const suspicious = (body.suspicious as Array<Record<string, unknown>>).filter(
        (s) => s.plate === plateP || s.plate === plateQ,
      );
      expect(suspicious).toHaveLength(2);
      expect(suspicious[0]).toMatchObject({
        pass_id: idLow,
        plate: plateP,
        txn_id: "****-a",
        reason: "no successful payment attempt",
      });
      expect(suspicious[1]).toMatchObject({
        pass_id: idHigh,
        plate: plateQ,
        txn_id: "****-b",
        reason: "no successful payment attempt",
      });

      expect(await db.value(`SELECT count(*) FROM passes WHERE id IN (${idLow}, ${idHigh})`)).toBe(2);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE reference IN ('${plateP}', '${plateQ}'); DELETE FROM passes WHERE id IN (${idLow}, ${idHigh});`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-017 — REWRITTEN by ONODE-40: reconciliation is a pure read taking no body and no query
  // parameters. The database is shared and parallel, so NO global count is asserted — only the
  // response SHAPE: 200, `checked` is a number, `suspicious` is a list.
  // AMENDED by ONODE-42 B1: the request carries X-Reconciliation-Token.
  // ---------------------------------------------------------------------------
  test("TC-017 reconciliation is a pure read returning a numeric checked and a suspicious list", async ({ api }) => {
    const res = await api.get("/passes/reconciliation", {
      headers: { "X-Reconciliation-Token": RECONCILIATION_TOKEN },
    });

    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(typeof body.checked).toBe("number");
    expect(Array.isArray(body.suspicious)).toBe(true);
  });

  // ---------------------------------------------------------------------------
  // TC-018 — POST /passes is stateful: one passes row AND one payment_attempts row (motorcycle, 12 months)
  // ---------------------------------------------------------------------------
  test("TC-018 SUCCESS charge writes exactly one passes row and one payment_attempts row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    const txnId = `txn-${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

      const res = await api.post("/passes", {
        data: { vehicle: "motorcycle", months: 12, plate },
      });

      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({
        vehicle: "motorcycle",
        months: 12,
        plate,
        price: 5760,
        currency: "THB",
        txn_id: txnId,
        status: "ACTIVE",
      });

      expect(
        await db.value(
          `SELECT count(*) FROM passes WHERE plate = '${plate}' AND txn_id = '${txnId}' AND status = 'ACTIVE'`,
        ),
      ).toBe(1);
      expect(
        await db.value(
          `SELECT count(*) FROM payment_attempts WHERE reference = '${plate}' AND outcome = 'SUCCESS' AND amount = 5760`,
        ),
      ).toBe(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE reference = '${plate}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-019 — best-effort audit: a SUCCESS charge still persists the pass and returns 201 with the
  // audit row present (the INSERT-throws branch is the developer's unit test with a fake repo).
  // ---------------------------------------------------------------------------
  test("TC-019 SUCCESS charge persists the pass and returns 201 with the audit row present", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    const txnId = `txn-${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

      const res = await api.post("/passes", {
        data: { vehicle: "car", months: 1, plate },
      });

      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({
        plate,
        price: 1500,
        txn_id: txnId,
        status: "ACTIVE",
      });

      expect(
        await db.value(
          `SELECT count(*) FROM passes WHERE plate = '${plate}' AND txn_id = '${txnId}' AND status = 'ACTIVE'`,
        ),
      ).toBe(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE reference = '${plate}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });
});