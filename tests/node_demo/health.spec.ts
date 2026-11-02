import { expect, test } from "@playwright/test";

test("GET /health answers 200 with status ok", async ({ request }) => {
  const res = await request.get("/health");
  expect(res.status()).toBe(200);
  expect(await res.json()).toEqual({ status: "ok" });
});
