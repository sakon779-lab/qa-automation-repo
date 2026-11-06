import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-26 — [WEB] the "ซื้อเลย" (buy) button on GET /web/quote must be genuinely INVISIBLE
 * (computed visibility) until a quote succeeds, and must disappear again on every error state.
 *
 * The bug: the page sets `buyEl.hidden = true` correctly, but the page CSS `.buy { display:inline-block }`
 * overrides the browser's `[hidden] { display:none }` default, so the button renders anyway. The fix is
 * CSS/markup only (`.buy[hidden] { display:none }`). Every "not visible" assertion here is a real
 * visibility assertion (toBeHidden / not.toBeVisible) — never a check of the `hidden` attribute, which
 * is present in the buggy version too (that is why the old tests stayed green while the page was wrong).
 *
 * One test per approved CSV row (TC-001 … TC-010), titled with its CaseID. UI rows end with a
 * screenshot into the visual gate (results/playwright/shots/<KEY>-<CaseID>.png).
 */
test.describe("ONODE-26 — /web/quote buy-button visibility", () => {
  // ---------------------------------------------------------------------------
  // TC-001 — initial page load: page renders, buy button NOT visible (visibility assertion)
  // ---------------------------------------------------------------------------
  test("TC-001 initial page load renders the page and the buy button is not visible", async ({ page }) => {
    const res = await page.goto("/web/quote");
    expect(res?.status()).toBe(200);

    const html = await page.content();
    for (const needle of [
      "ONODE Parking",
      "รถยนต์",
      "มอเตอร์ไซค์",
      "จำนวนเดือน",
      "ดูราคา",
      'data-testid="buy-button"',
    ]) {
      expect(html).toContain(needle);
    }

    // Visibility assertion — NOT an attribute check.
    await expect(page.getByTestId("buy-button")).toBeHidden();

    await page.screenshot({ path: `results/playwright/shots/ONODE-26-TC-001.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-002 — click ดูราคา with no vehicle selected → 'vehicle is required', buy button NOT visible
  // ---------------------------------------------------------------------------
  test("TC-002 quote with no vehicle shows 'vehicle is required' and the buy button is not visible", async ({
    page,
  }) => {
    const res = await page.goto("/web/quote");
    expect(res?.status()).toBe(200);

    // Leave vehicle unselected; click the quote button.
    await page.getByTestId("quote-button").click();

    await expect(page.getByTestId("error-message")).toHaveText("vehicle is required");
    await expect(page.getByTestId("buy-button")).toBeHidden();

    const html = await page.content();
    expect(html).toContain("ONODE Parking");
    expect(html).toContain("vehicle is required");

    await page.screenshot({ path: `results/playwright/shots/ONODE-26-TC-002.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-003 — quote call fails with intercepted 500 → Thai error string, buy button NOT visible
  // ---------------------------------------------------------------------------
  test("TC-003 a 500 from the quote call shows the Thai error and the buy button is not visible", async ({
    page,
  }) => {
    const res = await page.goto("/web/quote");
    expect(res?.status()).toBe(200);

    // Intercept the browser's POST /passes/quote and answer 500.
    await page.route("**/passes/quote", (route) =>
      route.fulfill({ status: 500, contentType: "application/json", body: JSON.stringify({ detail: "boom" }) }),
    );

    await page.getByTestId("vehicle-car").click();
    await page.getByTestId("months-input").fill("3");
    await page.getByTestId("quote-button").click();

    await expect(page.getByTestId("error-message")).toHaveText("ไม่สามารถคำนวณราคาได้ในขณะนี้ กรุณาลองใหม่");
    await expect(page.getByTestId("buy-button")).toBeHidden();

    const html = await page.content();
    expect(html).toContain("ONODE Parking");
    expect(html).toContain("ไม่สามารถคำนวณราคาได้ในขณะนี้ กรุณาลองใหม่");

    await page.screenshot({ path: `results/playwright/shots/ONODE-26-TC-003.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-004 — successful quote (car, 3 months) → 4500 THB, discount 0%, monthly rate, buy VISIBLE + href
  // ---------------------------------------------------------------------------
  test("TC-004 a successful car/3-month quote shows the price and makes the buy button visible with its href", async ({
    page,
  }) => {
    const res = await page.goto("/web/quote");
    expect(res?.status()).toBe(200);

    await page.getByTestId("vehicle-car").click();
    await page.getByTestId("months-input").fill("3");
    await page.getByTestId("quote-button").click();

    await expect(page.getByTestId("quote-price")).toHaveText("4500 THB");
    await expect(page.getByTestId("quote-discount")).toHaveText("discount 0%");
    await expect(page.getByTestId("quote-monthly-rate")).toHaveText("ราคาต่อเดือน 1500 THB");

    const buy = page.getByTestId("buy-button");
    await expect(buy).toBeVisible();
    await expect(buy).toHaveAttribute("href", "/web/buy?vehicle=car&months=3");

    const html = await page.content();
    for (const needle of ["4500 THB", "discount 0%", "ราคาต่อเดือน 1500 THB", "ซื้อเลย"]) {
      expect(html).toContain(needle);
    }

    await page.screenshot({ path: `results/playwright/shots/ONODE-26-TC-004.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-005 — after a success, a failed quote (months 13) clears the result and hides the buy button
  // ---------------------------------------------------------------------------
  test("TC-005 a failed quote after a success clears the result and hides the buy button again", async ({ page }) => {
    const res = await page.goto("/web/quote");
    expect(res?.status()).toBe(200);

    // First: a successful quote → buy button VISIBLE.
    await page.getByTestId("vehicle-car").click();
    await page.getByTestId("months-input").fill("3");
    await page.getByTestId("quote-button").click();

    await expect(page.getByTestId("quote-price")).toHaveText("4500 THB");
    await expect(page.getByTestId("quote-discount")).toHaveText("discount 0%");
    await expect(page.getByTestId("quote-monthly-rate")).toHaveText("ราคาต่อเดือน 1500 THB");
    await expect(page.getByTestId("buy-button")).toBeVisible();

    // Then: months 13 → 400 error, buy button must be hidden again (no stale visibility).
    await page.getByTestId("months-input").fill("13");
    await page.getByTestId("quote-button").click();

    await expect(page.getByTestId("error-message")).toHaveText("months must be an integer from 1 to 12");
    await expect(page.getByTestId("buy-button")).toBeHidden();

    const html = await page.content();
    expect(html).toContain("months must be an integer from 1 to 12");

    await page.screenshot({ path: `results/playwright/shots/ONODE-26-TC-005.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-006 — GET /web/quote stays public: 200, text/html, no redirect, not JSON
  // ---------------------------------------------------------------------------
  test("TC-006 GET /web/quote is public and answers 200 text/html without redirecting", async ({ api }) => {
    const res = await api.get("/web/quote", { maxRedirects: 0 });

    expect(res.status()).toBe(200);
    expect(res.headers()["content-type"] ?? "").toContain("text/html");

    const body = await res.text();
    expect(body).toContain("ONODE Parking");
    expect(body).toContain('data-testid="quote-screen"');

    // Not JSON: the body must not parse as a JSON object.
    let parsed: unknown = undefined;
    try {
      parsed = JSON.parse(body);
    } catch {
      parsed = undefined;
    }
    expect(parsed).toBeUndefined();
  });

  // ---------------------------------------------------------------------------
  // TC-007 — every ONODE-24 data-testid and wording string is preserved character for character
  // ---------------------------------------------------------------------------
  test("TC-007 the page keeps every ONODE-24 data-testid and wording string", async ({ api }) => {
    const res = await api.get("/web/quote");
    expect(res.status()).toBe(200);

    const html = await res.text();
    for (const needle of [
      'data-testid="quote-screen"',
      'data-testid="vehicle-car"',
      'data-testid="vehicle-motorcycle"',
      'data-testid="months-input"',
      'data-testid="quote-button"',
      'data-testid="quote-price"',
      'data-testid="quote-discount"',
      'data-testid="quote-monthly-rate"',
      'data-testid="buy-button"',
      'data-testid="error-message"',
      "ONODE Parking",
      "รถยนต์",
      "มอเตอร์ไซค์",
      "จำนวนเดือน",
      "ดูราคา",
      "ซื้อเลย",
      "ไม่สามารถคำนวณราคาได้ในขณะนี้ กรุณาลองใหม่",
    ]) {
      expect(html).toContain(needle);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-008 — buy button carries the hidden attribute in the initial markup AND the CSS makes a
  // hidden .buy compute to display:none
  // ---------------------------------------------------------------------------
  test("TC-008 the buy button carries the hidden attribute and the CSS makes a hidden .buy display:none", async ({
    api,
  }) => {
    const res = await api.get("/web/quote");
    expect(res.status()).toBe(200);

    const html = await res.text();
    expect(html).toContain('data-testid="buy-button"');
    expect(html).toContain("hidden");
    expect(html).toContain(".buy[hidden]");
    expect(html).toContain("display:none");

    // The buy-button element itself carries the hidden attribute in the initial markup.
    expect(html).toMatch(/<[^>]*data-testid="buy-button"[^>]*\bhidden\b/);
  });

  // ---------------------------------------------------------------------------
  // TC-009 — "not visible" is proven by a real visibility assertion, not the hidden attribute
  // ---------------------------------------------------------------------------
  test("TC-009 the buy button is not visible by computed visibility, not by the hidden attribute", async ({
    page,
  }) => {
    const res = await page.goto("/web/quote");
    expect(res?.status()).toBe(200);

    const html = await page.content();
    expect(html).toContain('data-testid="buy-button"');

    // Real visibility assertion — the attribute alone is NOT the proof.
    await expect(page.getByTestId("buy-button")).toBeHidden();

    await page.screenshot({ path: `results/playwright/shots/ONODE-26-TC-009.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-010 — no API/body/error-string change: POST /passes/quote body unchanged, ONODE-24 error verbatim
  // ---------------------------------------------------------------------------
  test("TC-010 the quote request body is unchanged and the error string is the ONODE-24 string verbatim", async ({
    page,
  }) => {
    const res = await page.goto("/web/quote");
    expect(res?.status()).toBe(200);

    // Capture the outgoing POST /passes/quote request body.
    const quoteRequest = page.waitForRequest(
      (req) => req.method() === "POST" && new URL(req.url()).pathname === "/passes/quote",
    );

    await page.getByTestId("vehicle-car").click();
    await page.getByTestId("months-input").fill("3");
    await page.getByTestId("quote-button").click();

    const req = await quoteRequest;
    expect(req.postDataJSON()).toEqual({ vehicle: "car", months: 3 });

    // The successful quote renders the ONODE-24 result strings.
    await expect(page.getByTestId("quote-price")).toHaveText("4500 THB");
    await expect(page.getByTestId("quote-discount")).toHaveText("discount 0%");
    await expect(page.getByTestId("quote-monthly-rate")).toHaveText("ราคาต่อเดือน 1500 THB");
    await expect(page.getByTestId("buy-button")).toBeVisible();

    const successHtml = await page.content();
    for (const needle of ["4500 THB", "discount 0%", "ราคาต่อเดือน 1500 THB", "ซื้อเลย"]) {
      expect(successHtml).toContain(needle);
    }

    // Then months 13 → the ONODE-24 error string verbatim (the result is cleared, so only the
    // error string remains in the DOM at this point).
    await page.getByTestId("months-input").fill("13");
    await page.getByTestId("quote-button").click();

    await expect(page.getByTestId("error-message")).toHaveText("months must be an integer from 1 to 12");

    const errorHtml = await page.content();
    expect(errorHtml).toContain("months must be an integer from 1 to 12");

    await page.screenshot({ path: `results/playwright/shots/ONODE-26-TC-010.png`, fullPage: true });
  });
});