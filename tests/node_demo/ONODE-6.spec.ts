import { expect, test } from "@playwright/test";

/**
 * ONODE-6 — POST /passes/quote & /passes/refund-quote input validation (plus regression
 * guards for the unchanged pricing/refund bodies and the untouched /fees/quote endpoint).
 * One test per approved CSV row; every row is a single stateless API call, so no
 * arrange/teardown state is required (the CSV declares none).
 *
 * FINDING (TC-014): the CSV Steps for TC-014 send only {vehicle, months} to /fees/quote,
 * but that endpoint requires additional fields (entered_at, exited_at, ...). The row's
 * intent — /fees/quote untouched, 200 with currency THB — is preserved here by supplying
 * the required fields; the CSV payload is incomplete and should be corrected.
 */
test.describe("ONODE-6 — pass quote & refund-quote validation", () => {
  test("TC-001 quote with vehicle null → 400 'vehicle is required'", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: null, months: 1 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle is required" });
  });

  test("TC-002 refund-quote with whitespace-only vehicle → 400 'vehicle is required'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "   ", months_bought: 6, months_used: 1 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle is required" });
  });

  test("TC-003 quote with vehicle 123 (number) → 400 'vehicle must be car or motorcycle'", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: 123, months: 1 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle must be car or motorcycle" });
  });

  test("TC-004 refund-quote with vehicle {} and months_bought 13 → 400 'vehicle must be car or motorcycle' (vehicle error wins)", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: {}, months_bought: 13, months_used: 1 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle must be car or motorcycle" });
  });

  test("TC-005 quote with vehicle 'Car' (wrong case) → 400 'vehicle must be car or motorcycle'", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "Car", months: 1 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle must be car or motorcycle" });
  });

  test("TC-006 quote with months missing → 400 'months is required'", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "car" },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months is required" });
  });

  test("TC-007 quote with months 13 → 400 'months must be an integer from 1 to 12'", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "car", months: 13 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months must be an integer from 1 to 12" });
  });

  test("TC-008 refund-quote with months_bought missing → 400 'months_bought is required'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "car", months_used: 1 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months_bought is required" });
  });

  test("TC-009 refund-quote with months_bought 13 → 400 'months_bought must be an integer from 1 to 12'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "car", months_bought: 13, months_used: 1 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months_bought must be an integer from 1 to 12" });
  });

  test("TC-010 refund-quote with months_used missing → 400 'months_used is required'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "car", months_bought: 6 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months_used is required" });
  });

  test("TC-011 refund-quote with months_used 7 > months_bought 6 → 400 'months_used must be an integer from 0 to months_bought'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "car", months_bought: 6, months_used: 7 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months_used must be an integer from 0 to months_bought" });
  });

  test("TC-012 quote car, 6 months → 200 unchanged pricing (discount 10%, price 8100, THB)", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "car", months: 6 },
    });
    expect(res.status()).toBe(200);
    expect(await res.json()).toEqual({
      vehicle: "car",
      months: 6,
      discount_percent: 10,
      price: 8100,
      currency: "THB",
    });
  });

  test("TC-013 refund-quote motorcycle, 6 bought, 1 used → 200 unchanged refund (paid 3240, used_value 600, fee 200, refund 2440)", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "motorcycle", months_bought: 6, months_used: 1 },
    });
    expect(res.status()).toBe(200);
    expect(await res.json()).toEqual({
      vehicle: "motorcycle",
      months_bought: 6,
      months_used: 1,
      paid: 3240,
      used_value: 600,
      fee: 200,
      refund: 2440,
      currency: "THB",
    });
  });

  test("TC-014 fees/quote (ONODE-1) untouched → 200 with currency THB", async ({ request }) => {
    // /fees/quote requires fields the CSV Steps omit (see FINDING above).
    const enteredAt = new Date(Date.now() - 60 * 60 * 1000).toISOString();
    const exitedAt = new Date().toISOString();
    const res = await request.post("/fees/quote", {
      data: { vehicle: "car", months: 6, entered_at: enteredAt, exited_at: exitedAt },
    });
    const body = await res.json();
    expect(res.status(), `fees/quote body: ${JSON.stringify(body)}`).toBe(200);
    expect(body).toMatchObject({ currency: "THB" });
  });
});