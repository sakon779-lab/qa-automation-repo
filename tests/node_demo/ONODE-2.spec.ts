import { expect, test } from "@playwright/test";

/**
 * ONODE-2 — POST /passes/quote pricing & validation.
 * One test per approved CSV row; each row is a single stateless API call, so no
 * arrange/teardown state is required (the CSV declares none).
 */
test.describe("ONODE-2 — POST /passes/quote", () => {
  test("TC-001 car, 1 month → 0% discount, 1500 THB", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "car", months: 1 },
    });
    expect(res.status()).toBe(200);
    expect(await res.json()).toEqual({
      vehicle: "car",
      months: 1,
      discount_percent: 0,
      price: 1500,
      currency: "THB",
    });
  });

  test("TC-002 motorcycle, 1 month → 0% discount, 600 THB", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "motorcycle", months: 1 },
    });
    expect(res.status()).toBe(200);
    expect(await res.json()).toEqual({
      vehicle: "motorcycle",
      months: 1,
      discount_percent: 0,
      price: 600,
      currency: "THB",
    });
  });

  test("TC-003 car, 5 months → 0% discount, 7500 THB (0% tier upper boundary)", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "car", months: 5 },
    });
    expect(res.status()).toBe(200);
    expect(await res.json()).toEqual({
      vehicle: "car",
      months: 5,
      discount_percent: 0,
      price: 7500,
      currency: "THB",
    });
  });

  test("TC-004 car, 6 months → 10% discount, 8100 THB (10% tier lower boundary)", async ({ request }) => {
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

  test("TC-005 motorcycle, 7 months → 10% discount, 3780 THB", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "motorcycle", months: 7 },
    });
    expect(res.status()).toBe(200);
    expect(await res.json()).toEqual({
      vehicle: "motorcycle",
      months: 7,
      discount_percent: 10,
      price: 3780,
      currency: "THB",
    });
  });

  test("TC-006 car, 11 months → 10% discount, 14850 THB (10% tier upper boundary)", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "car", months: 11 },
    });
    expect(res.status()).toBe(200);
    expect(await res.json()).toEqual({
      vehicle: "car",
      months: 11,
      discount_percent: 10,
      price: 14850,
      currency: "THB",
    });
  });

  test("TC-007 car, 12 months → 20% discount, 14400 THB", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "car", months: 12 },
    });
    expect(res.status()).toBe(200);
    expect(await res.json()).toEqual({
      vehicle: "car",
      months: 12,
      discount_percent: 20,
      price: 14400,
      currency: "THB",
    });
  });

  test("TC-008 motorcycle, 12 months → 20% discount, 5760 THB", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "motorcycle", months: 12 },
    });
    expect(res.status()).toBe(200);
    expect(await res.json()).toEqual({
      vehicle: "motorcycle",
      months: 12,
      discount_percent: 20,
      price: 5760,
      currency: "THB",
    });
  });

  test("TC-009 empty vehicle → 400 'vehicle is required'", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "", months: 3 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle is required" });
  });

  test("TC-010 absent vehicle → 400 'vehicle is required'", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { months: 3 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle is required" });
  });

  test("TC-011 vehicle 'Car' (wrong case) → 400 'vehicle must be car or motorcycle'", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "Car", months: 3 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle must be car or motorcycle" });
  });

  test("TC-012 vehicle 'truck' (unknown) → 400 'vehicle must be car or motorcycle'", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "truck", months: 3 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle must be car or motorcycle" });
  });

  test("TC-013 months null → 400 'months is required'", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "car", months: null },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months is required" });
  });

  test("TC-014 absent months → 400 'months is required' (validation order)", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "car" },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months is required" });
  });

  test("TC-015 months 0 → 400 'months must be an integer from 1 to 12'", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "car", months: 0 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months must be an integer from 1 to 12" });
  });

  test("TC-016 months 13 → 400 'months must be an integer from 1 to 12'", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "car", months: 13 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months must be an integer from 1 to 12" });
  });

  test("TC-017 months 1.5 → 400 'months must be an integer from 1 to 12'", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "car", months: 1.5 },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months must be an integer from 1 to 12" });
  });

  test("TC-018 months '3' (string) → 400 'months must be an integer from 1 to 12'", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "car", months: "3" },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months must be an integer from 1 to 12" });
  });
});