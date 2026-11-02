import { expect, test } from "@playwright/test";

/**
 * ONODE-2 — POST /passes/quote (monthly pass quote).
 *
 * Pure calculation endpoint: no database, no state. Every case is a single request whose
 * response body is asserted verbatim against the approved test design (test_designs/ONODE-2.csv).
 * Because the endpoint is stateless there is nothing to arrange or tear down.
 */
test.describe("ONODE-2 — POST /passes/quote monthly pass quote", () => {
  test("TC-001 car, 1 month → 0% discount, price 1500", async ({ request }) => {
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

  test("TC-002 motorcycle, 1 month → 0% discount, price 600", async ({ request }) => {
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

  test("TC-003 car, 5 months → 0% discount, price 7500 (0% tier upper boundary)", async ({
    request,
  }) => {
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

  test("TC-004 car, 6 months → 10% discount, price 8100 (10% tier lower boundary)", async ({
    request,
  }) => {
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

  test("TC-005 motorcycle, 7 months → 10% discount, price 3780", async ({ request }) => {
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

  test("TC-006 car, 11 months → 10% discount, price 14850 (10% tier upper boundary)", async ({
    request,
  }) => {
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

  test("TC-007 car, 12 months → 20% discount, price 14400", async ({ request }) => {
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

  test("TC-008 motorcycle, 12 months → 20% discount, price 5760", async ({ request }) => {
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

  test("TC-009 empty vehicle string → 400 vehicle is required", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "", months: 3 },
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle is required" });
  });

  test("TC-010 vehicle absent → 400 vehicle is required", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { months: 3 },
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle is required" });
  });

  test("TC-011 vehicle 'Car' (wrong case) → 400 vehicle must be car or motorcycle", async ({
    request,
  }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "Car", months: 3 },
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle must be car or motorcycle" });
  });

  test("TC-012 vehicle 'truck' (unknown type) → 400 vehicle must be car or motorcycle", async ({
    request,
  }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "truck", months: 3 },
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle must be car or motorcycle" });
  });

  test("TC-013 months null (valid vehicle) → 400 months is required", async ({ request }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "car", months: null },
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months is required" });
  });

  test("TC-014 months absent (valid vehicle, validation order) → 400 months is required", async ({
    request,
  }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "car" },
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months is required" });
  });

  test("TC-015 months 0 (below range) → 400 months must be an integer from 1 to 12", async ({
    request,
  }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "car", months: 0 },
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months must be an integer from 1 to 12" });
  });

  test("TC-016 months 13 (above range) → 400 months must be an integer from 1 to 12", async ({
    request,
  }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "car", months: 13 },
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months must be an integer from 1 to 12" });
  });

  test("TC-017 months 1.5 (non-integer number) → 400 months must be an integer from 1 to 12", async ({
    request,
  }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "car", months: 1.5 },
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months must be an integer from 1 to 12" });
  });

  test("TC-018 months '3' (string, not a number) → 400 months must be an integer from 1 to 12", async ({
    request,
  }) => {
    const res = await request.post("/passes/quote", {
      data: { vehicle: "car", months: "3" },
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months must be an integer from 1 to 12" });
  });
});