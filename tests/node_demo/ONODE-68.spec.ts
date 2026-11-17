import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-68 — the app-instance not-found handler: every unmatched route answers the fixed
 * constant body { detail: 'Not Found' } with Content-Type application/json, never the
 * framework default serializer, never caller-controlled path text, and never intercepting a
 * registered route or a route-owned 404.
 *
 * Every row here is stateless (Mock: None, no SQL, no teardown), so no test seeds or cleans
 * anything: each one only calls the deployed QA stack through the `api` fixture.
 */
test.describe("ONODE-68 — constant not-found handler", () => {
  test("TC-001 unmatched route GET /nope answers 404 with the fixed constant body", async ({ api }) => {
    const res = await api.get("/nope");
    expect(res.status()).toBe(404);
    expect(await res.json()).toEqual({ detail: "Not Found" });
  });

  test("TC-003 DELETE /passes/1 stays 404 with the constant body and no 405 is introduced", async ({ api }) => {
    const res = await api.delete("/passes/1");
    expect(res.status()).toBe(404);
    expect(res.status()).not.toBe(405);
    expect(await res.json()).toEqual({ detail: "Not Found" });
  });

  test("TC-005 the not-found body never reflects caller-controlled path text", async ({ api }) => {
    const res = await api.get("/nope/%3Cscript%3Ealert(1)%3C/script%3E");
    expect(res.status()).toBe(404);
    const body = await res.json();
    expect(body).toEqual({ detail: "Not Found" });
    const raw = JSON.stringify(body).toLowerCase();
    expect(raw).not.toContain("script");
    expect(raw).not.toContain("alert");
  });

  test("TC-006 the 404 body carries no framework keys", async ({ api }) => {
    const res = await api.get("/nope");
    expect(res.status()).toBe(404);
    const body = (await res.json()) as Record<string, unknown>;
    expect(body).toEqual({ detail: "Not Found" });
    expect(body).not.toHaveProperty("message");
    expect(body).not.toHaveProperty("error");
    expect(body).not.toHaveProperty("statusCode");
  });

  test("TC-007 the 404 response Content-Type is application/json", async ({ api }) => {
    const res = await api.get("/nope");
    expect(res.status()).toBe(404);
    expect(res.headers()["content-type"]).toContain("application/json");
    expect(await res.json()).toEqual({ detail: "Not Found" });
  });

  test("TC-008 a route-owned 404 is unchanged and not intercepted", async ({ api }) => {
    const res = await api.get("/passes/999999999");
    expect(res.status()).toBe(404);
    expect(await res.json()).toEqual({ detail: "pass not found" });
  });

  test("TC-009 the delivered /health route still answers 200 { status: 'ok' }", async ({ api }) => {
    const res = await api.get("/health");
    expect(res.status()).toBe(200);
    expect(await res.json()).toEqual({ status: "ok" });
  });

  test("TC-010 the app-instance not-found handler takes effect for GET /nope", async ({ api }) => {
    const res = await api.get("/nope");
    expect(res.status()).toBe(404);
    const body = (await res.json()) as Record<string, unknown>;
    expect(body).toEqual({ detail: "Not Found" });
    expect(body).not.toHaveProperty("message");
    expect(body).not.toHaveProperty("error");
    expect(body).not.toHaveProperty("statusCode");
  });

  test("TC-011 an unmatched path under the passes prefix answers the constant body", async ({ api }) => {
    const res = await api.get("/passes/abc/extra");
    expect(res.status()).toBe(404);
    expect(await res.json()).toEqual({ detail: "Not Found" });
  });

  test("TC-004 POST /nope with a JSON body answers 404 application/json with the constant body", async ({ api }) => {
    const res = await api.post("/nope", {
      headers: { "Content-Type": "application/json" },
      data: {},
    });
    expect(res.status()).toBe(404);
    expect(res.headers()["content-type"]).toContain("application/json");
    expect(await res.json()).toEqual({ detail: "Not Found" });
  });
});
