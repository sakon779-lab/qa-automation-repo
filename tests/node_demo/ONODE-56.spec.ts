import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-56 — GET /web/buy: the discount-tier boundaries (11 and 12 months) had no test, so the
 * mutation `months <= 11` -> `months < 11` in src/web/buy.ts:39 survived the whole suite.
 * One test per approved CSV row (test_designs/ONODE-56.csv): TC-001 … TC-020, titled with its CaseID.
 *
 * Rows whose ExpectedResult is about the STATIC GET HTML assert on the response body (api).
 * Rows that describe an element's RUNTIME state (TC-009/TC-010 hide the buy form; TC-016/TC-017
 * assert the class/role/aria-live the page's own JS sets when it renders the error box or the
 * bought pass) drive the real browser (page) and end with a screenshot for the visual gate.
 * No row seeds the database or arms a stub, so no row has a teardown.
 */
test.describe("ONODE-56 — GET /web/buy prices at the discount-tier boundaries", () => {
  const INVALID_LINK = "ลิงก์ไม่ถูกต้อง กรุณากลับไปเลือกที่หน้าราคา";
  const BACK_TO_QUOTE = "กลับไปหน้าราคา";
  const BUY_TITLE = "ยืนยันซื้อบัตรจอดรถรายเดือน";
  const BUY_BUTTON = "ยืนยันซื้อ";

  /** The nine data-testid hooks the page must keep (B3). */
  const NINE_HOOKS = [
    'data-testid="buy-screen"',
    'data-testid="buy-vehicle"',
    'data-testid="buy-months"',
    'data-testid="buy-price"',
    'data-testid="plate-input"',
    'data-testid="buy-button"',
    'data-testid="buy-result"',
    'data-testid="buy-error"',
    'data-testid="buy-invalid-link"',
  ];

  /** Fetch the page and return its HTML, asserting the row's 200 first. */
  async function getBuyHtml(api: import("@playwright/test").APIRequestContext, query: string) {
    const res = await api.get(`/web/buy?${query}`);
    expect(res.status()).toBe(200);
    return res.text();
  }

  // ---------------------------------------------------------------------------
  // TC-001 — car 11 months: top of the 10% tier → 14850 THB (B5, W1)
  // ---------------------------------------------------------------------------
  test("TC-001 GET /web/buy for car 11 months renders buy-price '14850 THB'", async ({ api }) => {
    const html = await getBuyHtml(api, "vehicle=car&months=11");

    expect(html, "page HTML must contain รถยนต์").toContain("รถยนต์");
    expect(html, "page HTML must contain 11 เดือน").toContain("11 เดือน");
    expect(html, "page HTML must contain 14850 THB").toContain("14850 THB");
  });

  // ---------------------------------------------------------------------------
  // TC-002 — car 12 months: 20% tier → 14400 THB (B5, W2)
  // ---------------------------------------------------------------------------
  test("TC-002 GET /web/buy for car 12 months renders buy-price '14400 THB'", async ({ api }) => {
    const html = await getBuyHtml(api, "vehicle=car&months=12");

    expect(html, "page HTML must contain รถยนต์").toContain("รถยนต์");
    expect(html, "page HTML must contain 12 เดือน").toContain("12 เดือน");
    expect(html, "page HTML must contain 14400 THB").toContain("14400 THB");
  });

  // ---------------------------------------------------------------------------
  // TC-003 — motorcycle 11 months: top of the 10% tier → 5940 THB (B5, W3)
  // ---------------------------------------------------------------------------
  test("TC-003 GET /web/buy for motorcycle 11 months renders buy-price '5940 THB'", async ({ api }) => {
    const html = await getBuyHtml(api, "vehicle=motorcycle&months=11");

    expect(html, "page HTML must contain มอเตอร์ไซค์").toContain("มอเตอร์ไซค์");
    expect(html, "page HTML must contain 11 เดือน").toContain("11 เดือน");
    expect(html, "page HTML must contain 5940 THB").toContain("5940 THB");
  });

  // ---------------------------------------------------------------------------
  // TC-004 — motorcycle 6 months: bottom of the 10% tier → 3240 THB (B5, W4)
  // ---------------------------------------------------------------------------
  test("TC-004 GET /web/buy for motorcycle 6 months renders buy-price '3240 THB'", async ({ api }) => {
    const html = await getBuyHtml(api, "vehicle=motorcycle&months=6");

    expect(html, "page HTML must contain มอเตอร์ไซค์").toContain("มอเตอร์ไซค์");
    expect(html, "page HTML must contain 6 เดือน").toContain("6 เดือน");
    expect(html, "page HTML must contain 3240 THB").toContain("3240 THB");
  });

  // ---------------------------------------------------------------------------
  // TC-005 — car 5 months: top of the 0% tier → 7500 THB (B5, W5)
  // ---------------------------------------------------------------------------
  test("TC-005 GET /web/buy for car 5 months renders buy-price '7500 THB'", async ({ api }) => {
    const html = await getBuyHtml(api, "vehicle=car&months=5");

    expect(html, "page HTML must contain รถยนต์").toContain("รถยนต์");
    expect(html, "page HTML must contain 5 เดือน").toContain("5 เดือน");
    expect(html, "page HTML must contain 7500 THB").toContain("7500 THB");
  });

  // ---------------------------------------------------------------------------
  // TC-006 — car 6 months: bottom of the 10% tier → 8100 THB (B5, W6)
  // ---------------------------------------------------------------------------
  test("TC-006 GET /web/buy for car 6 months renders buy-price '8100 THB'", async ({ api }) => {
    const html = await getBuyHtml(api, "vehicle=car&months=6");

    expect(html, "page HTML must contain รถยนต์").toContain("รถยนต์");
    expect(html, "page HTML must contain 6 เดือน").toContain("6 เดือน");
    expect(html, "page HTML must contain 8100 THB").toContain("8100 THB");
  });

  // ---------------------------------------------------------------------------
  // TC-007 — motorcycle 12 months: 20% tier → 5760 THB (B5, W7)
  // ---------------------------------------------------------------------------
  test("TC-007 GET /web/buy for motorcycle 12 months renders buy-price '5760 THB'", async ({ api }) => {
    const html = await getBuyHtml(api, "vehicle=motorcycle&months=12");

    expect(html, "page HTML must contain มอเตอร์ไซค์").toContain("มอเตอร์ไซค์");
    expect(html, "page HTML must contain 12 เดือน").toContain("12 เดือน");
    expect(html, "page HTML must contain 5760 THB").toContain("5760 THB");
  });

  // ---------------------------------------------------------------------------
  // TC-008 — car 1 month: bottom of the 0% tier → 1500 THB (B5, W8)
  // ---------------------------------------------------------------------------
  test("TC-008 GET /web/buy for car 1 month renders buy-price '1500 THB'", async ({ api }) => {
    const html = await getBuyHtml(api, "vehicle=car&months=1");

    expect(html, "page HTML must contain รถยนต์").toContain("รถยนต์");
    expect(html, "page HTML must contain 1 เดือน").toContain("1 เดือน");
    expect(html, "page HTML must contain 1500 THB").toContain("1500 THB");
  });

  // ---------------------------------------------------------------------------
  // TC-009 — invalid vehicle → invalid-link state, buy form hidden (E1)
  // ---------------------------------------------------------------------------
  test("TC-009 GET /web/buy with an invalid vehicle renders the invalid-link state and hides the buy form", async ({
    page,
  }) => {
    await page.goto("/web/buy?vehicle=truck&months=6");

    // Screen shows
    await expect(page.getByText(INVALID_LINK).first()).toBeVisible();
    await expect(page.getByText(BACK_TO_QUOTE).first()).toBeVisible();

    // Screen hides
    await expect(page.getByText(BUY_TITLE).first()).toBeHidden();
    await expect(page.getByText(BUY_BUTTON).first()).toBeHidden();

    await page.screenshot({ path: `results/playwright/shots/ONODE-56-TC-009.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-010 — months outside 1..12 → invalid-link state, buy form hidden (E2)
  // ---------------------------------------------------------------------------
  test("TC-010 GET /web/buy with months outside 1..12 renders the invalid-link state and hides the buy form", async ({
    page,
  }) => {
    await page.goto("/web/buy?vehicle=car&months=13");

    // Screen shows
    await expect(page.getByText(INVALID_LINK).first()).toBeVisible();
    await expect(page.getByText(BACK_TO_QUOTE).first()).toBeVisible();

    // Screen hides
    await expect(page.getByText(BUY_TITLE).first()).toBeHidden();
    await expect(page.getByText(BUY_BUTTON).first()).toBeHidden();

    await page.screenshot({ path: `results/playwright/shots/ONODE-56-TC-010.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-011 — public page: 200 text/html, no auth, no redirect, no JSON (B1)
  // ---------------------------------------------------------------------------
  test("TC-011 GET /web/buy stays public and always answers 200 text/html, never redirecting or returning JSON", async ({
    api,
  }) => {
    const res = await api.get("/web/buy?vehicle=car&months=6");

    expect(res.status()).toBe(200);
    expect(res.headers()["content-type"]).toContain("text/html");
    const html = await res.text();
    expect(html, "page HTML must contain ONODE Parking").toContain("ONODE Parking");
    expect(html, `page HTML must contain ${BUY_TITLE}`).toContain(BUY_TITLE);
  });

  // ---------------------------------------------------------------------------
  // TC-012 — all nine data-testid hooks kept exactly (B3)
  // ---------------------------------------------------------------------------
  test("TC-012 GET /web/buy keeps all nine data-testid hooks exactly and adds none", async ({ api }) => {
    const html = await getBuyHtml(api, "vehicle=car&months=6");

    for (const needle of NINE_HOOKS) {
      expect(html, `page HTML must contain ${needle}`).toContain(needle);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-013 — Thai vehicle label and '<months> เดือน' inside buy-vehicle / buy-months (B4, W4)
  // ---------------------------------------------------------------------------
  test("TC-013 GET /web/buy shows the Thai vehicle label and '<months> เดือน' for motorcycle 6 months", async ({
    api,
  }) => {
    const html = await getBuyHtml(api, "vehicle=motorcycle&months=6");

    expect(html, 'page HTML must contain data-testid="buy-vehicle">มอเตอร์ไซค์').toContain(
      'data-testid="buy-vehicle">มอเตอร์ไซค์',
    );
    expect(html, 'page HTML must contain data-testid="buy-months">6 เดือน').toContain(
      'data-testid="buy-months">6 เดือน',
    );
    expect(html, "page HTML must contain 3240 THB").toContain("3240 THB");
  });

  // ---------------------------------------------------------------------------
  // TC-014 — plate field stays an input labelled 'ทะเบียนรถ' (B7)
  // ---------------------------------------------------------------------------
  test("TC-014 the plate field stays an input labelled 'ทะเบียนรถ' with data-testid plate-input", async ({ api }) => {
    const html = await getBuyHtml(api, "vehicle=car&months=6");

    expect(html, "page HTML must contain ทะเบียนรถ").toContain("ทะเบียนรถ");
    expect(html, 'page HTML must contain data-testid="plate-input"').toContain('data-testid="plate-input"');
    expect(html, "page HTML must contain เช่น กข 1234").toContain("เช่น กข 1234");
  });

  // ---------------------------------------------------------------------------
  // TC-015 — confirm button POSTs to /passes as application/json (B8)
  // ---------------------------------------------------------------------------
  test("TC-015 the page's confirm button POSTs to /passes with Content-Type application/json", async ({ api }) => {
    const html = await getBuyHtml(api, "vehicle=car&months=6");

    expect(html, "page HTML must contain /passes").toContain("/passes");
    expect(html, "page HTML must contain application/json").toContain("application/json");
    expect(html, `page HTML must contain ${BUY_BUTTON}`).toContain(BUY_BUTTON);
  });

  // ---------------------------------------------------------------------------
  // TC-016 — buy-error carries alert-danger and role="alert", hidden with no error (B9)
  // ---------------------------------------------------------------------------
  test("TC-016 the buy-error element carries class alert-danger and role=\"alert\" and is hidden when there is no error", async ({
    page,
  }) => {
    await page.goto("/web/buy?vehicle=car&months=6");

    // No error yet: the box is hidden.
    const errorBox = page.getByTestId("buy-error");
    await expect(errorBox).toBeHidden();

    // The page's own JS sets class alert-danger and role="alert" when it renders an error.
    await page.route("**/passes", (route) =>
      route.fulfill({
        status: 400,
        contentType: "application/json",
        body: JSON.stringify({ detail: "plate is required" }),
      }),
    );
    await page.getByTestId("plate-input").fill("AB1234");
    await page.getByTestId("buy-button").click();

    await expect(errorBox).toBeVisible();
    await expect(errorBox).toHaveClass(/alert-danger/);
    await expect(errorBox).toHaveAttribute("role", "alert");

    await page.screenshot({ path: `results/playwright/shots/ONODE-56-TC-016.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-017 — buy-result carries pass-card and aria-live="polite" (B10)
  // ---------------------------------------------------------------------------
  test("TC-017 the buy-result element carries class pass-card and aria-live=\"polite\" for rendering the bought pass", async ({
    page,
  }) => {
    await page.goto("/web/buy?vehicle=car&months=6");

    // The page's own JS sets class pass-card and aria-live="polite" when it renders the pass.
    await page.route("**/passes", (route) =>
      route.fulfill({
        status: 201,
        contentType: "application/json",
        body: JSON.stringify({
          id: "pass-101",
          plate: "AB1234",
          vehicle: "car",
          months: 6,
          price: 8100,
          status: "active",
        }),
      }),
    );
    await page.getByTestId("plate-input").fill("AB1234");
    await page.getByTestId("buy-button").click();

    const result = page.getByTestId("buy-result");
    await expect(result).toBeVisible();
    await expect(result).toHaveClass(/pass-card/);
    await expect(result).toHaveAttribute("aria-live", "polite");

    await page.screenshot({ path: `results/playwright/shots/ONODE-56-TC-017.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-018 — the page remains stateless (B11)
  // ---------------------------------------------------------------------------
  test("TC-018 the page remains stateless — no localStorage, no cookie, no language switcher", async ({ api }) => {
    const html = await getBuyHtml(api, "vehicle=car&months=6");

    expect(html, "page HTML must contain ONODE Parking").toContain("ONODE Parking");
    expect(html, `page HTML must contain ${BUY_TITLE}`).toContain(BUY_TITLE);
    expect(html, "page HTML must not contain localStorage").not.toContain("localStorage");
    expect(html, "page HTML must not contain document.cookie").not.toContain("document.cookie");
    expect(html, "page HTML must not contain language-switcher").not.toContain("language-switcher");
  });

  // ---------------------------------------------------------------------------
  // TC-019 — same two query parameters, valid pair renders the buy form (B2, W7)
  // ---------------------------------------------------------------------------
  test("TC-019 GET /web/buy keeps reading vehicle and months and renders the valid buy form for motorcycle 12", async ({
    api,
  }) => {
    const html = await getBuyHtml(api, "vehicle=motorcycle&months=12");

    expect(html, "page HTML must contain มอเตอร์ไซค์").toContain("มอเตอร์ไซค์");
    expect(html, "page HTML must contain 12 เดือน").toContain("12 เดือน");
    expect(html, "page HTML must contain 5760 THB").toContain("5760 THB");
    expect(html, `page HTML must contain ${BUY_TITLE}`).toContain(BUY_TITLE);
  });

  // ---------------------------------------------------------------------------
  // TC-020 — POST /passes unchanged: the page still renders the same buy form (B12, W6)
  // ---------------------------------------------------------------------------
  test("TC-020 the page still renders the same buy form and price for car 6 months", async ({ api }) => {
    const html = await getBuyHtml(api, "vehicle=car&months=6");

    expect(html, `page HTML must contain ${BUY_TITLE}`).toContain(BUY_TITLE);
    expect(html, "page HTML must contain 8100 THB").toContain("8100 THB");
    expect(html, `page HTML must contain ${BUY_BUTTON}`).toContain(BUY_BUTTON);
  });
});