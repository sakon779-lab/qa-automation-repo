import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-24 — GET /web/quote: the public web twin of the ONODE-14 mobile screen.
 * One test per approved CSV row (TC-001 … TC-015), titled with its CaseID.
 *
 * The page is a single HTML document with inline JS that calls the existing
 * POST /passes/quote. Every UI row drives the real browser page and ends with a
 * screenshot into the visual gate (results/playwright/shots/ONODE-24-<CaseID>.png).
 *
 * TC-010 / TC-011 / TC-013 intercept POST /passes/quote with page.route — correct here
 * because what is under test is the PAGE's own JS in the browser, not the app server's
 * outbound call (the ticket explicitly sanctions page.route for these).
 */
test.describe("ONODE-24 — GET /web/quote public pricing page", () => {
  const FALLBACK = "ไม่สามารถคำนวณราคาได้ในขณะนี้ กรุณาลองใหม่";

  // ---------------------------------------------------------------------------
  // TC-001 — public page: 200 text/html, no cookie, no auth header
  // ---------------------------------------------------------------------------
  test("TC-001 GET /web/quote is public and answers 200 text/html with no cookie and no auth header", async ({
    api,
  }) => {
    const res = await api.get("/web/quote");

    expect(res.status()).toBe(200);
    expect(res.headers()["content-type"]).toContain("text/html");
    const html = await res.text();
    expect(html).toContain("ONODE Parking");
  });

  // ---------------------------------------------------------------------------
  // TC-002 — the rendered page carries the heading and all ten data-testid hooks
  // ---------------------------------------------------------------------------
  test("TC-002 GET /web/quote renders the heading and all ten data-testid hooks", async ({ api }) => {
    const res = await api.get("/web/quote");

    expect(res.status()).toBe(200);
    const html = await res.text();
    for (const needle of [
      "ONODE Parking",
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
    ]) {
      expect(html, `page HTML must contain ${needle}`).toContain(needle);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-003 — car, 3 months → 4500 THB, discount 0%, rate 1500 THB
  // ---------------------------------------------------------------------------
  test("TC-003 car with 3 months renders 4500 THB, discount 0% and rate 1500 THB", async ({ page }) => {
    await page.goto("/web/quote");
    await page.getByTestId("vehicle-car").click();
    await page.getByTestId("months-input").fill("3");
    await page.getByTestId("quote-button").click();

    await expect(page.getByTestId("quote-price")).toHaveText("4500 THB");
    await expect(page.getByTestId("quote-discount")).toHaveText("discount 0%");
    await expect(page.getByTestId("quote-monthly-rate")).toHaveText("ราคาต่อเดือน 1500 THB");
    await expect(page.getByTestId("buy-button")).toHaveText("ซื้อเลย");

    await page.screenshot({ path: `results/playwright/shots/ONODE-24-TC-003.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-004 — car, 6 months → 8100 THB, discount 10%, rate 1500 THB
  // ---------------------------------------------------------------------------
  test("TC-004 car with 6 months renders 8100 THB, discount 10% and rate 1500 THB", async ({ page }) => {
    await page.goto("/web/quote");
    await page.getByTestId("vehicle-car").click();
    await page.getByTestId("months-input").fill("6");
    await page.getByTestId("quote-button").click();

    await expect(page.getByTestId("quote-price")).toHaveText("8100 THB");
    await expect(page.getByTestId("quote-discount")).toHaveText("discount 10%");
    await expect(page.getByTestId("quote-monthly-rate")).toHaveText("ราคาต่อเดือน 1500 THB");
    await expect(page.getByTestId("buy-button")).toHaveText("ซื้อเลย");

    await page.screenshot({ path: `results/playwright/shots/ONODE-24-TC-004.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-005 — motorcycle, 12 months → 5760 THB, discount 20%, rate 600 THB, buy href
  // ---------------------------------------------------------------------------
  test("TC-005 motorcycle with 12 months renders 5760 THB, discount 20%, rate 600 THB and buy href", async ({
    page,
  }) => {
    await page.goto("/web/quote");
    await page.getByTestId("vehicle-motorcycle").click();
    await page.getByTestId("months-input").fill("12");
    await page.getByTestId("quote-button").click();

    await expect(page.getByTestId("quote-price")).toHaveText("5760 THB");
    await expect(page.getByTestId("quote-discount")).toHaveText("discount 20%");
    await expect(page.getByTestId("quote-monthly-rate")).toHaveText("ราคาต่อเดือน 600 THB");
    await expect(page.getByTestId("buy-button")).toHaveText("ซื้อเลย");
    await expect(page.getByTestId("buy-button")).toHaveAttribute(
      "href",
      "/web/buy?vehicle=motorcycle&months=12",
    );

    await page.screenshot({ path: `results/playwright/shots/ONODE-24-TC-005.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-006 — no vehicle selected, months 3 → 'vehicle is required'
  // ---------------------------------------------------------------------------
  test("TC-006 no vehicle selected with months 3 renders 'vehicle is required'", async ({ page }) => {
    await page.goto("/web/quote");
    await page.getByTestId("months-input").fill("3");
    await page.getByTestId("quote-button").click();

    await expect(page.getByTestId("error-message")).toHaveText("vehicle is required");

    await page.screenshot({ path: `results/playwright/shots/ONODE-24-TC-006.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-007 — car selected, blank months → 'months is required'
  // ---------------------------------------------------------------------------
  test("TC-007 car selected with blank months renders 'months is required'", async ({ page }) => {
    await page.goto("/web/quote");
    await page.getByTestId("vehicle-car").click();
    await page.getByTestId("quote-button").click();

    await expect(page.getByTestId("error-message")).toHaveText("months is required");

    await page.screenshot({ path: `results/playwright/shots/ONODE-24-TC-007.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-008 — car, months 13 → 'months must be an integer from 1 to 12'
  // ---------------------------------------------------------------------------
  test("TC-008 car with months 13 renders 'months must be an integer from 1 to 12'", async ({ page }) => {
    await page.goto("/web/quote");
    await page.getByTestId("vehicle-car").click();
    await page.getByTestId("months-input").fill("13");
    await page.getByTestId("quote-button").click();

    await expect(page.getByTestId("error-message")).toHaveText("months must be an integer from 1 to 12");

    await page.screenshot({ path: `results/playwright/shots/ONODE-24-TC-008.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-009 — car, non-integer months '1.5' → 'months must be an integer from 1 to 12'
  // ---------------------------------------------------------------------------
  test("TC-009 car with non-integer months '1.5' renders 'months must be an integer from 1 to 12'", async ({
    page,
  }) => {
    await page.goto("/web/quote");
    await page.getByTestId("vehicle-car").click();
    await page.getByTestId("months-input").fill("1.5");
    await page.getByTestId("quote-button").click();

    await expect(page.getByTestId("error-message")).toHaveText("months must be an integer from 1 to 12");

    await page.screenshot({ path: `results/playwright/shots/ONODE-24-TC-009.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-010 — quote call answers HTTP 500 → Thai fallback message
  // ---------------------------------------------------------------------------
  test("TC-010 a server error from the quote call renders the Thai fallback message", async ({ page }) => {
    await page.route("**/passes/quote", (route) =>
      route.fulfill({ status: 500, contentType: "application/json", body: JSON.stringify({ detail: "boom" }) }),
    );

    await page.goto("/web/quote");
    await page.getByTestId("vehicle-car").click();
    await page.getByTestId("months-input").fill("3");
    await page.getByTestId("quote-button").click();

    await expect(page.getByTestId("error-message")).toHaveText(FALLBACK);

    await page.screenshot({ path: `results/playwright/shots/ONODE-24-TC-010.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-011 — quote call answers 200 with a non-JSON body → Thai fallback message
  // ---------------------------------------------------------------------------
  test("TC-011 a 200 non-JSON body from the quote call renders the Thai fallback message", async ({ page }) => {
    await page.route("**/passes/quote", (route) =>
      route.fulfill({ status: 200, contentType: "text/plain", body: "not json" }),
    );

    await page.goto("/web/quote");
    await page.getByTestId("vehicle-car").click();
    await page.getByTestId("months-input").fill("3");
    await page.getByTestId("quote-button").click();

    await expect(page.getByTestId("error-message")).toHaveText(FALLBACK);

    await page.screenshot({ path: `results/playwright/shots/ONODE-24-TC-011.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-012 — a failing quote after a successful one clears price/discount/rate/buy
  // ---------------------------------------------------------------------------
  test("TC-012 a failing quote after a successful one removes the previous price, discount, rate and buy button", async ({
    page,
  }) => {
    await page.goto("/web/quote");
    await page.getByTestId("vehicle-car").click();
    await page.getByTestId("months-input").fill("3");
    await page.getByTestId("quote-button").click();

    await expect(page.getByTestId("quote-price")).toHaveText("4500 THB");
    await expect(page.getByTestId("quote-discount")).toHaveText("discount 0%");
    await expect(page.getByTestId("quote-monthly-rate")).toHaveText("ราคาต่อเดือน 1500 THB");
    await expect(page.getByTestId("buy-button")).toHaveText("ซื้อเลย");

    await page.getByTestId("months-input").fill("13");
    await page.getByTestId("quote-button").click();

    await expect(page.getByTestId("error-message")).toHaveText("months must be an integer from 1 to 12");
    await expect(page.getByTestId("quote-price")).toBeEmpty();
    await expect(page.getByTestId("quote-discount")).toBeEmpty();
    await expect(page.getByTestId("quote-monthly-rate")).toBeEmpty();
    await expect(page.getByTestId("buy-button")).toBeHidden();

    await page.screenshot({ path: `results/playwright/shots/ONODE-24-TC-012.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-013 — a second tap while the first request is in flight disables the button
  //         and clears prior output before the new answer arrives
  // ---------------------------------------------------------------------------
  test("TC-013 a second tap while the first request is in flight disables the button and clears prior output", async ({
    page,
  }) => {
    await page.route("**/passes/quote", async (route) => {
      await new Promise((resolve) => setTimeout(resolve, 3000));
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ vehicle: "car", months: 3, discount_percent: 0, price: 4500, currency: "THB" }),
      });
    });

    await page.goto("/web/quote");
    await page.getByTestId("vehicle-car").click();
    await page.getByTestId("months-input").fill("3");
    await page.getByTestId("quote-button").click();
    // Second tap while the first request is still in flight.
    await page.getByTestId("quote-button").click();

    await expect(page.getByTestId("quote-screen")).toContainText("ONODE Parking");
    await expect(page.getByTestId("quote-screen")).toContainText("ดูราคา");
    await expect(page.getByTestId("quote-button")).toBeDisabled();
    await expect(page.getByTestId("quote-price")).toBeEmpty();
    await expect(page.getByTestId("quote-discount")).toBeEmpty();
    await expect(page.getByTestId("quote-monthly-rate")).toBeEmpty();
    await expect(page.getByTestId("buy-button")).toBeHidden();
    await expect(page.getByTestId("error-message")).toBeEmpty();

    await page.screenshot({ path: `results/playwright/shots/ONODE-24-TC-013.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-014 — the page is stateless: a successful quote is not remembered after reload
  // ---------------------------------------------------------------------------
  test("TC-014 the page is stateless: a successful quote is not remembered after reload", async ({ page }) => {
    await page.goto("/web/quote");
    await page.getByTestId("vehicle-car").click();
    await page.getByTestId("months-input").fill("3");
    await page.getByTestId("quote-button").click();

    await expect(page.getByTestId("quote-price")).toHaveText("4500 THB");
    await expect(page.getByTestId("quote-discount")).toHaveText("discount 0%");
    await expect(page.getByTestId("quote-monthly-rate")).toHaveText("ราคาต่อเดือน 1500 THB");
    await expect(page.getByTestId("buy-button")).toHaveText("ซื้อเลย");

    await page.reload();

    await expect(page.getByTestId("quote-screen")).toContainText("ONODE Parking");
    await expect(page.getByTestId("quote-screen")).toContainText("รถยนต์");
    await expect(page.getByTestId("quote-screen")).toContainText("มอเตอร์ไซค์");
    await expect(page.getByTestId("quote-screen")).toContainText("จำนวนเดือน");
    await expect(page.getByTestId("quote-screen")).toContainText("ดูราคา");
    await expect(page.getByTestId("quote-price")).toBeEmpty();
    await expect(page.getByTestId("quote-discount")).toBeEmpty();
    await expect(page.getByTestId("quote-monthly-rate")).toBeEmpty();
    await expect(page.getByTestId("buy-button")).toBeHidden();
    await expect(page.getByTestId("error-message")).toBeEmpty();

    await page.screenshot({ path: `results/playwright/shots/ONODE-24-TC-014.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-015 — the page only renders the existing POST /passes/quote result, car 3 months
  // ---------------------------------------------------------------------------
  test("TC-015 the page only renders the existing quote result: car 3 months still shows 4500 THB / discount 0%", async ({
    page,
  }) => {
    await page.goto("/web/quote");
    await page.getByTestId("vehicle-car").click();
    await page.getByTestId("months-input").fill("3");
    await page.getByTestId("quote-button").click();

    await expect(page.getByTestId("quote-price")).toHaveText("4500 THB");
    await expect(page.getByTestId("quote-discount")).toHaveText("discount 0%");
    await expect(page.getByTestId("quote-monthly-rate")).toHaveText("ราคาต่อเดือน 1500 THB");
    await expect(page.getByTestId("buy-button")).toHaveText("ซื้อเลย");

    await page.screenshot({ path: `results/playwright/shots/ONODE-24-TC-015.png`, fullPage: true });
  });
});