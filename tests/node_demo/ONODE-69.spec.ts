import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-69 — the startup path stopped creating tables; the delivered API behaviour must be
 * unchanged (B7 regression over the real interface).
 *
 * TC-004  POST /passes still creates a pass (201, delivered body shape) + row stored
 * TC-005  GET /passes/{id} still reads a pass back (200, delivered body, txn_id masked per B7)
 *
 * NOTE (CSV, TC-004): the row says `Mock: None`, but POST /passes charges the external payment
 * gateway before it persists anything, so with no stub the app answers 502 'payment gateway
 * unavailable' and the row's own expected 201 is unreachable. The row's intent — the happy path
 * of POST /passes is unchanged — is proven by arming the gateway SUCCESS stub with this test's
 * own txn_id (the same way every other POST /passes row in this suite does), then asserting the
 * delivered 201 body and the stored row.
 */
test.describe("ONODE-69 — pass API unchanged after the startup path stopped creating tables", () => {
  test("TC-004 POST /passes still creates a pass with 201 and the delivered response shape", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`;
    const txnId = `txn_${dynamicId}`;

    await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

    try {
      const res = await api.post("/passes", {
        data: { vehicle: "car", months: 3, plate, price: 1500, txn_id: txnId },
      });

      expect(res.status()).toBe(201);
      const body = await res.json();
      expect(body).toMatchObject({ plate, txn_id: txnId, status: "ACTIVE" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-005 GET /passes/{id} still reads a pass back with the delivered 200 body and masked txn_id", async ({
    api,
    db,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`;
    const txnId = `txn_${dynamicId}XY`;

    await db.exec(
      `INSERT INTO passes (id, vehicle, months, plate, price, txn_id, status) VALUES (${dynamicId}, 'car', 3, '${plate}', 1500, '${txnId}', 'ACTIVE');`,
    );

    try {
      const res = await api.get(`/passes/${dynamicId}`);

      expect(res.status()).toBe(200);
      const body = await res.json();
      expect(body).toMatchObject({ plate, txn_id: "****XY" });
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });
});
