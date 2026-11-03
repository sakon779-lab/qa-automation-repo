import { expect, test } from "@playwright/test";

/**
 * ONODE-4 — POST /passes/refund-quote refund calculation & validation.
 * One test per approved CSV row; each row is a single stateless API call, so no
 * arrange/teardown state is required (the CSV declares none).
 */
test.describe("ONODE-4 — POST /passes/refund-quote", () => {
  test("TC-001 car, 12 months (20% tier), 0 used → paid 14400, used_value 0, fee 200, refund 14200", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "car", months_bought: 12, months_used: 0 },
    });
    expect(res.status()).toBe(200);
    expect(await res.json()).toEqual({
      vehicle: "car",
      months_bought: 12,
      months_used: 0,
      paid: 14400,
      used_value: 0,
      fee: 200,
      refund: 14200,
      currency: "THB",
    });
  });

  test("TC-002 car, 12 months (20% tier), 3 used → paid 14400, used_value 4500, fee 200, refund 9700", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "car", months_bought: 12, months_used: 3 },
    });
    expect(res.status()).toBe(200);
    expect(await res.json()).toEqual({
      vehicle: "car",
      months_bought: 12,
      months_used: 3,
      paid: 14400,
      used_value: 4500,
      fee: 200,
      refund: 9700,
      currency: "THB",
    });
  });

  test("TC-003 car, 6 months (10% tier boundary), 5 used → paid 8100, used_value 7500, fee 200, refund 400", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "car", months_bought: 6, months_used: 5 },
    });
    expect(res.status()).toBe(200);
    expect(await res.json()).toEqual({
      vehicle: "car",
      months_bought: 6,
      months_used: 5,
      paid: 8100,
      used_value: 7500,
      fee: 200,
      refund: 400,
      currency: "THB",
    });
  });

  test("TC-004 car, 6 months, 6 used (fully used) → paid 8100, used_value 9000, fee 200, refund clamped to 0", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "car", months_bought: 6, months_used: 6 },
    });
    expect(res.status()).toBe(200);
    expect(await res.json()).toEqual({
      vehicle: "car",
      months_bought: 6,
      months_used: 6,
      paid: 8100,
      used_value: 9000,
      fee: 200,
      refund: 0,
      currency: "THB",
    });
  });

  test("TC-005 car, 1 month (lowest tier, 0% discount), 0 used → paid 1500, used_value 0, fee 200, refund 1300", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "car", months_bought: 1, months_used: 0 },
    });
    expect(res.status()).toBe(200);
    expect(await res.json()).toEqual({
      vehicle: "car",
      months_bought: 1,
      months_used: 0,
      paid: 1500,
      used_value: 0,
      fee: 200,
      refund: 1300,
      currency: "THB",
    });
  });

  test("TC-006 motorcycle, 3 months, 1 used → paid 1800, used_value 600, fee 200, refund 1000", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "motorcycle", months_bought: 3, months_used: 1 },
    });
    expect(res.status()).toBe(200);
    expect(await res.json()).toEqual({
      vehicle: "motorcycle",
      months_bought: 3,
      months_used: 1,
      paid: 1800,
      used_value: 600,
      fee: 200,
      refund: 1000,
      currency: "THB",
    });
  });

  test("TC-007 motorcycle, 7 months (10% tier), 2 used → paid 3780, used_value 1200, fee 200, refund 2380", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "motorcycle", months_bought: 7, months_used: 2 },
    });
    expect(res.status()).toBe(200);
    expect(await res.json()).toEqual({
      vehicle: "motorcycle",
      months_bought: 7,
      months_used: 2,
      paid: 3780,
      used_value: 1200,
      fee: 200,
      refund: 2380,
      currency: "THB",
    });
  });

  test("TC-008 motorcycle, 12 months (20% tier), 9 used → paid 5760, used_value 5400, fee 200, refund 160", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "motorcycle", months_bought: 12, months_used: 9 },
    });
    expect(res.status()).toBe(200);
    expect(await res.json()).toEqual({
      vehicle: "motorcycle",
      months_bought: 12,
      months_used: 9,
      paid: 5760,
      used_value: 5400,
      fee: 200,
      refund: 160,
      currency: "THB",
    });
  });

  test("TC-009 motorcycle, 12 months, 10 used → paid 5760, used_value 6000, fee 200, refund clamped to 0", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "motorcycle", months_bought: 12, months_used: 10 },
    });
    expect(res.status()).toBe(200);
    expect(await res.json()).toEqual({
      vehicle: "motorcycle",
      months_bought: 12,
      months_used: 10,
      paid: 5760,
      used_value: 6000,
      fee: 200,
      refund: 0,
      currency: "THB",
    });
  });

  test("TC-010 absent vehicle → 400 'vehicle is required'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { months_bought: 6, months_used: 2 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle is required" });
  });

  test("TC-011 empty vehicle → 400 'vehicle is required'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "", months_bought: 6, months_used: 2 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle is required" });
  });

  test("TC-012 whitespace-only vehicle → 400 'vehicle is required'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "   ", months_bought: 6, months_used: 2 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle is required" });
  });

  test("TC-013 vehicle 'Car' (wrong case) → 400 'vehicle must be car or motorcycle'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "Car", months_bought: 6, months_used: 2 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle must be car or motorcycle" });
  });

  test("TC-014 vehicle 'truck' (unknown) → 400 'vehicle must be car or motorcycle'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "truck", months_bought: 6, months_used: 2 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle must be car or motorcycle" });
  });

  test("TC-015 SQL-injection vehicle string → 400 'vehicle must be car or motorcycle'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "'; DROP TABLE passes;--", months_bought: 6, months_used: 2 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle must be car or motorcycle" });
  });

  test("TC-016 absent months_bought → 400 'months_bought is required'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "car", months_used: 2 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months_bought is required" });
  });

  test("TC-017 months_bought null → 400 'months_bought is required'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "car", months_bought: null, months_used: 2 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months_bought is required" });
  });

  test("TC-018 months_bought 0 → 400 'months_bought must be an integer from 1 to 12'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "car", months_bought: 0, months_used: 0 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months_bought must be an integer from 1 to 12" });
  });

  test("TC-019 months_bought 13 → 400 'months_bought must be an integer from 1 to 12'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "car", months_bought: 13, months_used: 2 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months_bought must be an integer from 1 to 12" });
  });

  test("TC-020 months_bought 1.5 (float) → 400 'months_bought must be an integer from 1 to 12'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "car", months_bought: 1.5, months_used: 1 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months_bought must be an integer from 1 to 12" });
  });

  test("TC-021 months_bought '3' (string) → 400 'months_bought must be an integer from 1 to 12'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "car", months_bought: "3", months_used: 1 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months_bought must be an integer from 1 to 12" });
  });

  test("TC-022 absent months_used → 400 'months_used is required'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "car", months_bought: 6 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months_used is required" });
  });

  test("TC-023 months_used null → 400 'months_used is required'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "car", months_bought: 6, months_used: null },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months_used is required" });
  });

  test("TC-024 months_used -1 → 400 'months_used must be an integer from 0 to months_bought'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "car", months_bought: 6, months_used: -1 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months_used must be an integer from 0 to months_bought" });
  });

  test("TC-025 months_used 2.5 (float) → 400 'months_used must be an integer from 0 to months_bought'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "car", months_bought: 6, months_used: 2.5 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months_used must be an integer from 0 to months_bought" });
  });

  test("TC-026 months_used '2' (string) → 400 'months_used must be an integer from 0 to months_bought'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "car", months_bought: 6, months_used: "2" },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months_used must be an integer from 0 to months_bought" });
  });

  test("TC-027 months_used 7 exceeds months_bought 6 → 400 'months_used must be an integer from 0 to months_bought'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "car", months_bought: 6, months_used: 7 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months_used must be an integer from 0 to months_bought" });
  });

  test("TC-028 bad months_bought 13 short-circuits months_used 99 → 400 'months_bought must be an integer from 1 to 12'", async ({ request }) => {
    const res = await request.post("/passes/refund-quote", {
      data: { vehicle: "car", months_bought: 13, months_used: 99 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months_bought must be an integer from 1 to 12" });
  });
});