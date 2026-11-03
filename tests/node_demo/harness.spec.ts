import { test, expect } from "../../resources/playwright/fixtures";

/**
 * The harness proves itself before any card leans on it: resources/playwright/fixtures.ts must
 * reach the QA database, scope MockServer stubs to ONE test, and clean up after it. If these go
 * red, every stateful card's suite is wrong for a reason that is not the app.
 */
test.describe("harness — db and mock fixtures", () => {
  test("db runs statements and reads a count back as a number", async ({ db, dynamicId }) => {
    await db.exec(`CREATE TEMP TABLE harness_probe (id int); INSERT INTO harness_probe VALUES (${dynamicId});`);
    expect(await db.value(`SELECT count(*) FROM harness_probe WHERE id = ${dynamicId}`)).toBe(1);
    expect(await db.rows(`SELECT id FROM harness_probe`)).toEqual([{ id: dynamicId }]);
  });

  test("a stub answers only the test that armed it, and is gone after clear", async ({ mock, requestId, playwright, mockUrl }) => {
    await mock.arm("POST", "/harness-probe", 200, { ok: true });
    const client = await playwright.request.newContext({ baseURL: mockUrl });
    try {
      const mine = await client.post("/harness-probe", { headers: { "X-Request-Id": requestId }, data: {} });
      expect(mine.status()).toBe(200);
      expect(await mine.json()).toEqual({ ok: true });

      const other = await client.post("/harness-probe", { headers: { "X-Request-Id": "someone-else" }, data: {} });
      expect(other.status()).toBe(404);

      expect(await mock.received("POST", "/harness-probe")).toHaveLength(1);

      await mock.clear();
      const after = await client.post("/harness-probe", { headers: { "X-Request-Id": requestId }, data: {} });
      expect(after.status()).toBe(404);
    } finally {
      await client.dispose();
    }
  });

});
