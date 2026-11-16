import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-66 — the app's uniform not-found handler.
 *
 * Every row here is stateless: no seed, no stub, no teardown. The rows prove that an unmatched
 * path answers the app's own constant 404 body ({'detail': 'Not Found'}) instead of a framework
 * default, that a route-owned 404 keeps its own body, and that /health is untouched.
 */
test.describe("ONODE-66 — uniform not-found handler", () => {
  test("TC-001 GET /nope answers 404 with the uniform body and no framework keys", async ({ api }) => {
    const res = await api.get("/nope");

    expect(res.status()).toBe(404);
    const body = await res.json();
    expect(body).toEqual({ detail: "Not Found" });
    // no framework keys leaked into the body
    expect(body).not.toHaveProperty("error");
    expect(body).not.toHaveProperty("statusCode");
    expect(body).not.toHaveProperty("message");
  });

  test("TC-002 POST /nope with JSON {} answers 404 uniform body and application/json", async ({ api }) => {
    const res = await api.post("/nope", {
      headers: { "Content-Type": "application/json" },
      data: {},
    });

    expect(res.status()).toBe(404);
    expect(res.headers()["content-type"]).toContain("application/json");
    expect(await res.json()).toEqual({ detail: "Not Found" });
  });

  test("TC-003 DELETE /passes/1 stays 404 uniform body and no 405 is introduced", async ({ api }) => {
    const res = await api.delete("/passes/1");

    expect(res.status()).toBe(404);
    expect(res.status()).not.toBe(405);
    expect(await res.json()).toEqual({ detail: "Not Found" });
  });

  test("TC-004 GET /nope/<script>alert(1)</script> answers 404 and echoes nothing from the path", async ({ api }) => {
    const res = await api.get("/nope/%3Cscript%3Ealert(1)%3C%2Fscript%3E");

    expect(res.status()).toBe(404);
    const raw = await res.text();
    expect(JSON.parse(raw)).toEqual({ detail: "Not Found" });
    expect(raw).not.toContain("script");
    expect(raw).not.toContain("alert");
    expect(raw).not.toContain("/nope");
  });

  test("TC-005 GET /health still answers 200 {'status': 'ok'}", async ({ api }) => {
    const res = await api.get("/health");

    expect(res.status()).toBe(200);
    expect(await res.json()).toEqual({ status: "ok" });
  });

  test("TC-006 GET /passes/999999999 keeps the route's own 404 body, not the constant", async ({ api }) => {
    const res = await api.get("/passes/999999999");

    expect(res.status()).toBe(404);
    const body = await res.json();
    expect(body).toEqual({ detail: "pass not found" });
    expect(body).not.toEqual({ detail: "Not Found" });
  });
});
