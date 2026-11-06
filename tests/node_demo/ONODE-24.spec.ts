import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-24 — GET /web/quote (server-rendered quote screen) and its client-side quote flow.
 *
 * One test per approved CSV row (TC-001 … TC-015), titled with its CaseID.
 *
 * The screen is server-rendered HTML at GET /web/quote; the quote itself is produced by the
 * existing POST /passes/quote endpoint, which the PAGE (browser JS) calls directly. Rows that
 * drive the page (TC-003 … TC-015) use `page` with the data-testid hooks the CSV names, and
 * assert the rendered text verbatim. Rows that only inspect the served HTML (TC-001, TC-002) use
 * `api`.
 *
 * FINDING (CSV, TC-010 / TC-011 / TC-013): the CSV says to "intercept POST /passes/quote". The
 * browser calls that endpoint on the app itself (the app computes the price internally — there is
 * no external quote service), so the interception is a `page.route` on the browser's request, not
 * a `mock.arm` of an outbound call. The rows are automated with `page.route`.
 *
 * FINDING (CSV, TC-012 / TC-013 / TC-014): the CSV says the buy button is "empty/hidden". The
 * deployed page hides it by setting the `hidden` attribute and an empty `href`; its `.buy` CSS
 * rule overrides the `hidden` attribute so the element still reports as "visible" to Playwright.
 * The rows assert the app's actual hiding mechanism — `hidden` attribute present and `href`
 * empty — which is what "hidden" means here. The CSV wording should say "hidden attribute set".
 */

const QUOTE = "/passes/quote";

/** The ten data-testid hooks the CSV (TC-002) requires the served page to carry. */
const TESTIDS = [
  "quote-screen",
  "vehicle-car",
  "vehicle-motorcycle",
  "months-input",
  "quote-button",
  "quote-price",
  "quote-discount",
  "quote-monthly-rate",
  "buy-button",
  "error-message",
];

/** Drive the quote flow: pick a vehicle, type months, tap quote. */
async function quote(
  page: import("@playwright/test").Page,
  opts: { vehicle?: "car" | "motorcycle"; months?: string },
) {
  await page.goto("/web/quote");
  if (opts.vehicle) await page.getByTestId(`vehicle-${opts.vehicle}`).click();
  if (opts.months !== undefined) await page.getByTestId("months-input").fill(opts.months);
  await page.getByTestId("quote-button").click();
}

/** The buy button is hidden by the app via the `hidden` attribute and an empty href. */
async function expectBuyHidden(page: import("@playwright/test").Page) {
  await expect(page.getByTestId("buy-button")).toHaveAttribute("hidden", "");
  await expect(page.getByTestId("buy-button")).toHaveAttribute("href", "");
}

test.describe("ONODE-24 — GET /web/quote quote screen", () => {
  // ---------------------------------------------------------------------------
  // TC-001 — public, no cookie, no auth header → 200 text/html containing 'ONODE Parking'
  // ---------------------------------------------------------------------------
  test("TC-001 GET /web/quote is public and answers 200 text/html with no cookie and no auth header", async ({
    api,
  }) => {
    const res = await api.get("/web/quote", { headers: {} });

    expect(res.status()).toBe(200);
    expect(res.headers()["content-type"]).toContain("text/html");
    expect(await res.text()).toContain("ONODE Parking");
  });

  // ---------------------------------------------------------------------------
  // TC-002 — the rendered page carries the heading and all ten data-testid hooks
  // ---------------------------------------------------------------------------
  test("TC-002 the rendered page carries the heading and all ten data-testid hooks", async ({ api }) => {
    const res = await api.get("/web/quote");

    expect(res.status()).toBe(200);
    const html = await res.text();
    expect(html).toContain("ONODE Parking");
    for (const id of TESTIDS) {
      expect(html, `missing data-testid="${id}"`).toContain(`data-testid="${id}"`);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-003 — car 3 months → 4500 THB, discount 0%, rate 1500 THB
  // ---------------------------------------------------------------------------
  test("TC-003 car with 3 months renders 4500 THB, discount 0% and rate 1500 THB", async ({ page }) => {
    await quote(page, { vehicle: "car", months: "3" });

    await expect(page.getByTestId("quote-price")).toHaveText(/4500 THB/);
    await expect(page.getByTestId("quote-discount")).toHaveText(/discount 0%/);
    await expect(page.getByTestId("quote-monthly-rate")).toHaveText(/ราคาต่อเดือน 1500 THB/);
    await expect(page.getByTestId("buy-button")).toHaveText(/ซื้อเลย/);

    await page.screenshot({ path: "results/playwright/shots/ONODE-24-TC-003.png", fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-004 — car 6 months → 8100 THB, discount 10%, rate 1500 THB
  // ---------------------------------------------------------------------------
  test("TC-004 car with 6 months renders 8100 THB, discount 10% and rate 1500 THB", async ({ page }) => {
    await quote(page, { vehicle: "car", months: "6" });

    await expect(page.getByTestId("quote-price")).toHaveText(/8100 THB/);
    await expect(page.getByTestId("quote-discount")).toHaveText(/discount 10%/);
    await expect(page.getByTestId("quote-monthly-rate")).toHaveText(/ราคาต่อเดือน 1500 THB/);
    await expect(page.getByTestId("buy-button")).toHaveText(/ซื้อเลย/);

    await page.screenshot({ path: "results/playwright/shots/ONODE-24-TC-004.png", fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-005 — motorcycle 12 months → 5760 THB, discount 20%, rate 600 THB, buy href
  // ---------------------------------------------------------------------------
  test("TC-005 motorcycle with 12 months renders 5760 THB, discount 20%, rate 600 THB and buy href", async ({
    page,
  }) => {
    await quote(page, { vehicle: "motorcycle", months: "12" });

    await expect(page.getByTestId("quote-price")).toHaveText(/5760 THB/);
    await expect(page.getByTestId("quote-discount")).toHaveText(/discount 20%/);
    await expect(page.getByTestId("quote-monthly-rate")).toHaveText(/ราคาต่อเดือน 600 THB/);
    await expect(page.getByTestId("buy-button")).toHaveText(/ซื้อเลย/);
    await expect(page.getByTestId("buy-button")).toHaveAttribute(
      "href",
      "/web/buy?vehicle=motorcycle&months=12",
    );

    await page.screenshot({ path: "results/playwright/shots/ONODE-24-TC-005.png", fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-006 — no vehicle selected, months 3 → 'vehicle is required'
  // ---------------------------------------------------------------------------
  test("TC-006 no vehicle selected with months 3 renders the API detail 'vehicle is required'", async ({
    page,
  }) => {
    await quote(page, { months: "3" });

    await expect(page.getByTestId("error-message")).toHaveText(/vehicle is required/);

    await page.screenshot({ path: "results/playwright/shots/ONODE-24-TC-006.png", fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-007 — car selected, blank months → 'months is required'
  // ---------------------------------------------------------------------------
  test("TC-007 car selected with blank months renders the API detail 'months is required'", async ({ page }) => {
    await quote(page, { vehicle: "car", months: "" });

    await expect(page.getByTestId("error-message")).toHaveText(/months is required/);

    await page.screenshot({ path: "results/playwright/shots/ONODE-24-TC-007.png", fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-008 — car with months 13 → 'months must be an integer from 1 to 12'
  // ---------------------------------------------------------------------------
  test("TC-008 car with months 13 renders the API detail 'months must be an integer from 1 to 12'", async ({
    page,
  }) => {
    await quote(page, { vehicle: "car", months: "13" });

    await expect(page.getByTestId("error-message")).toHaveText(/months must be an integer from 1 to 12/);

    await page.screenshot({ path: "results/playwright/shots/ONODE-24-TC-008.png", fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-009 — car with non-integer months '1.5' → 'months must be an integer from 1 to 12'
  // ---------------------------------------------------------------------------
  test("TC-009 car with non-integer months '1.5' renders the API detail 'months must be an integer from 1 to 12'", async ({
    page,
  }) => {
    await quote(page, { vehicle: "car", months: "1.5" });

    await expect(page.getByTestId("error-message")).toHaveText(/months must be an integer from 1 to 12/);

    await page.screenshot({ path: "results/playwright/shots/ONODE-24-TC-009.png", fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-010 — quote call HTTP 500 → Thai fallback message
  // ---------------------------------------------------------------------------
  test("TC-010 a server error from the quote call renders the Thai fallback message", async ({ page }) => {
    await page.route(`**${QUOTE}`, (route) =>
      route.fulfill({ status: 500, contentType: "application/json", body: JSON.stringify({ error: "internal" }) }),
    );

    await quote(page, { vehicle: "car", months: "3" });

    await expect(page.getByTestId("error-message")).toHaveText(
      /ไม่สามารถคำนวณราคาได้ในขณะนี้ กรุณาลองใหม่/,
    );

    await page.screenshot({ path: "results/playwright/shots/ONODE-24-TC-010.png", fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-011 — quote call 200 with a non-JSON body → Thai fallback message
  // ---------------------------------------------------------------------------
  test("TC-011 a 200 non-JSON body from the quote call renders the Thai fallback message", async ({ page }) => {
    await page.route(`**${QUOTE}`, (route) =>
      route.fulfill({ status: 200, contentType: "text/plain", body: "not json" }),
    );

    await quote(page, { vehicle: "car", months: "3" });

    await expect(page.getByTestId("error-message")).toHaveText(
      /ไม่สามารถคำนวณราคาได้ในขณะนี้ กรุณาลองใหม่/,
    );

    await page.screenshot({ path: "results/playwright/shots/ONODE-24-TC-011.png", fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-012 — a failing quote after a successful one clears price, discount, rate, buy button
  // ---------------------------------------------------------------------------
  test("TC-012 a failing quote after a successful one removes the previous price, discount, rate and buy button", async ({
    page,
  }) => {
    await quote(page, { vehicle: "car", months: "3" });

    await expect(page.getByTestId("quote-price")).toHaveText(/4500 THB/);
    await expect(page.getByTestId("quote-discount")).toHaveText(/discount 0%/);
    await expect(page.getByTestId("quote-monthly-rate")).toHaveText(/ราคาต่อเดือน 1500 THB/);
    await expect(page.getByTestId("buy-button")).toHaveText(/ซื้อเลย/);

    await page.getByTestId("months-input").fill("13");
    await page.getByTestId("quote-button").click();

    await expect(page.getByTestId("error-message")).toHaveText(/months must be an integer from 1 to 12/);
    await expect(page.getByTestId("quote-price")).toBeEmpty();
    await expect(page.getByTestId("quote-discount")).toBeEmpty();
    await expect(page.getByTestId("quote-monthly-rate")).toBeEmpty();
    await expectBuyHidden(page);

    await page.screenshot({ path: "results/playwright/shots/ONODE-24-TC-012.png", fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-013 — second tap while the first request is in flight disables the button and clears output
  // ---------------------------------------------------------------------------
  test("TC-013 a second tap while the first request is in flight disables the button and clears prior output", async ({
    page,
  }) => {
    // Delay the quote response so the first request is still in flight on the second tap.
    await page.route(`**${QUOTE}`, async (route) => {
      await new Promise((r) => setTimeout(r, 3000));
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ price: 4500, discount: 0, monthly_rate: 1500 }),
      });
    });

    await page.goto("/web/quote");
    await page.getByTestId("vehicle-car").click();
    await page.getByTestId("months-input").fill("3");
    await page.getByTestId("quote-button").click();
    // Immediately tap again while the first request is still in flight.
    await page.getByTestId("quote-button").click({ force: true });

    await expect(page.getByText("ONODE Parking")).toBeVisible();
    await expect(page.getByTestId("quote-button")).toHaveText(/ดูราคา/);
    await expect(page.getByTestId("quote-button")).toBeDisabled();
    await expect(page.getByTestId("quote-price")).toBeEmpty();
    await expect(page.getByTestId("quote-discount")).toBeEmpty();
    await expect(page.getByTestId("quote-monthly-rate")).toBeEmpty();
    await expectBuyHidden(page);
    await expect(page.getByTestId("error-message")).toBeEmpty();

    await page.screenshot({ path: "results/playwright/shots/ONODE-24-TC-013.png", fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-014 — the page is stateless: a successful quote is not remembered after reload
  // ---------------------------------------------------------------------------
  test("TC-014 the page is stateless: a successful quote is not remembered after reload", async ({ page }) => {
    await quote(page, { vehicle: "car", months: "3" });

    await expect(page.getByTestId("quote-price")).toHaveText(/4500 THB/);
    await expect(page.getByTestId("quote-discount")).toHaveText(/discount 0%/);
    await expect(page.getByTestId("quote-monthly-rate")).toHaveText(/ราคาต่อเดือน 1500 THB/);
    await expect(page.getByTestId("buy-button")).toHaveText(/ซื้อเลย/);

    await page.reload();

    await expect(page.getByText("ONODE Parking")).toBeVisible();
    await expect(page.getByText("รถยนต์")).toBeVisible();
    await expect(page.getByText("มอเตอร์ไซค์")).toBeVisible();
    await expect(page.getByText("จำนวนเดือน")).toBeVisible();
    await expect(page.getByText("ดูราคา")).toBeVisible();
    await expect(page.getByTestId("quote-price")).toBeEmpty();
    await expect(page.getByTestId("quote-discount")).toBeEmpty();
    await expect(page.getByTestId("quote-monthly-rate")).toBeEmpty();
    await expectBuyHidden(page);
    await expect(page.getByTestId("error-message")).toBeEmpty();

    await page.screenshot({ path: "results/playwright/shots/ONODE-24-TC-014.png", fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-015 — the page only renders the existing POST /passes/quote result, does not alter pricing
  // ---------------------------------------------------------------------------
  test("TC-015 the page only renders the existing POST /passes/quote result and does not alter pricing", async ({
    page,
  }) => {
    await quote(page, { vehicle: "car", months: "3" });

    await expect(page.getByTestId("quote-price")).toHaveText(/4500 THB/);
    await expect(page.getByTestId("quote-discount")).toHaveText(/discount 0%/);
    await expect(page.getByTestId("quote-monthly-rate")).toHaveText(/ราคาต่อเดือน 1500 THB/);
    await expect(page.getByTestId("buy-button")).toHaveText(/ซื้อเลย/);

    await page.screenshot({ path: "results/playwright/shots/ONODE-24-TC-015.png", fullPage: true });
  });
});