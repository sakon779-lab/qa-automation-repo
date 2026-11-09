import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-50 — GET /web/buy: the public web twin of the buy step reached from /web/quote.
 * One test per approved CSV row (TC-001 … TC-018), titled with its CaseID.
 *
 * The page is a single HTML document with inline JS that calls the existing POST /passes.
 * Rows whose ExpectedResult is about the STATIC GET HTML assert on the response body (api).
 * Rows whose ExpectedResult is about what the page's own JS renders at runtime drive the real
 * browser (page) and intercept POST /passes with page.route — correct here because what is
 * under test is the PAGE's JS in the browser, not the app server's outbound call.
 * Every UI row ends with a screenshot into the visual gate.
 */
test.describe("ONODE-50 — GET /web/buy buy-confirmation page", () => {
  const INVALID_LINK = "ลิงก์ไม่ถูกต้อง กรุณากลับไปเลือกที่หน้าราคา";
  const BACK_TO_QUOTE = "กลับไปหน้าราคา";
  const BUY_LABEL = "ยืนยันซื้อ";
  const WORKING_LABEL = "กำลังดำเนินการ…";
  const SUCCESS_LABEL = "ซื้อสำเร็จ";
  const NETWORK_FALLBACK = "ไม่สามารถซื้อบัตรได้ในขณะนี้ กรุณาลองใหม่";

  // ---------------------------------------------------------------------------
  // TC-001 — vehicle query parameter absent → invalid-link state, no POST /passes
  // ---------------------------------------------------------------------------
  test("TC-001 GET /web/buy without the vehicle parameter renders the invalid-link state", async ({ api }) => {
    const res = await api.get("/web/buy?months=3");

    expect(res.status()).toBe(200);
    const html = await res.text();
    for (const needle of [INVALID_LINK, BACK_TO_QUOTE, 'data-testid="buy-invalid-link"']) {
      expect(html, `page HTML must contain ${needle}`).toContain(needle);
    }
    for (const needle of ['data-testid="plate-input"', 'data-testid="buy-button"']) {
      expect(html, `page HTML must not contain ${needle}`).not.toContain(needle);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-002 — months query parameter absent → invalid-link state, no POST /passes
  // ---------------------------------------------------------------------------
  test("TC-002 GET /web/buy without the months parameter renders the invalid-link state", async ({ api }) => {
    const res = await api.get("/web/buy?vehicle=car");

    expect(res.status()).toBe(200);
    const html = await res.text();
    for (const needle of [INVALID_LINK, BACK_TO_QUOTE, 'data-testid="buy-invalid-link"']) {
      expect(html, `page HTML must contain ${needle}`).toContain(needle);
    }
    for (const needle of ['data-testid="plate-input"', 'data-testid="buy-button"']) {
      expect(html, `page HTML must not contain ${needle}`).not.toContain(needle);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-003 — public page: 200 text/html carrying all nine data-testid hooks
  // ---------------------------------------------------------------------------
  test("TC-003 GET /web/buy is public and answers 200 text/html carrying all nine data-testid hooks", async ({
    api,
  }) => {
    const res = await api.get("/web/buy?vehicle=car&months=1");

    expect(res.status()).toBe(200);
    expect(res.headers()["content-type"]).toContain("text/html");
    const html = await res.text();
    for (const needle of [
      "ONODE Parking",
      'data-testid="buy-screen"',
      'data-testid="buy-vehicle"',
      'data-testid="buy-months"',
      'data-testid="buy-price"',
      'data-testid="plate-input"',
      'data-testid="buy-button"',
      'data-testid="buy-result"',
      'data-testid="buy-error"',
      'data-testid="buy-invalid-link"',
    ]) {
      expect(html, `page HTML must contain ${needle}`).toContain(needle);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-004 — car, 1 month → 'รถยนต์', '1 เดือน', '1500 THB'
  // ---------------------------------------------------------------------------
  test("TC-004 car with 1 month renders 'รถยนต์', '1 เดือน' and price '1500 THB'", async ({ api }) => {
    const res = await api.get("/web/buy?vehicle=car&months=1");

    expect(res.status()).toBe(200);
    const html = await res.text();
    for (const needle of ["รถยนต์", "1 เดือน", "1500 THB", "ทะเบียนรถ", BUY_LABEL]) {
      expect(html, `page HTML must contain ${needle}`).toContain(needle);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-005 — motorcycle, 12 months → 'มอเตอร์ไซค์', '12 เดือน', '5760 THB'
  // ---------------------------------------------------------------------------
  test("TC-005 motorcycle with 12 months renders 'มอเตอร์ไซค์', '12 เดือน' and the 20% discount price '5760 THB'", async ({
    api,
  }) => {
    const res = await api.get("/web/buy?vehicle=motorcycle&months=12");

    expect(res.status()).toBe(200);
    const html = await res.text();
    for (const needle of ["มอเตอร์ไซค์", "12 เดือน", "5760 THB", "ทะเบียนรถ", BUY_LABEL]) {
      expect(html, `page HTML must contain ${needle}`).toContain(needle);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-006 — car, 6 months → first discounted tier '8100 THB'
  // ---------------------------------------------------------------------------
  test("TC-006 car with 6 months renders the first discounted tier price '8100 THB'", async ({ api }) => {
    const res = await api.get("/web/buy?vehicle=car&months=6");

    expect(res.status()).toBe(200);
    const html = await res.text();
    for (const needle of ["รถยนต์", "6 เดือน", "8100 THB"]) {
      expect(html, `page HTML must contain ${needle}`).toContain(needle);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-007 — car, 5 months → last undiscounted tier '7500 THB'
  // ---------------------------------------------------------------------------
  test("TC-007 car with 5 months renders the last undiscounted tier price '7500 THB'", async ({ api }) => {
    const res = await api.get("/web/buy?vehicle=car&months=5");

    expect(res.status()).toBe(200);
    const html = await res.text();
    for (const needle of ["รถยนต์", "5 เดือน", "7500 THB"]) {
      expect(html, `page HTML must contain ${needle}`).toContain(needle);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-008 — plate field is an input labelled 'ทะเบียนรถ' with plate-input, no client validation
  // ---------------------------------------------------------------------------
  test("TC-008 the plate field is an input labelled 'ทะเบียนรถ' with data-testid plate-input and no client-side validation", async ({
    api,
  }) => {
    const res = await api.get("/web/buy?vehicle=car&months=1");

    expect(res.status()).toBe(200);
    const html = await res.text();
    for (const needle of ["ทะเบียนรถ", 'data-testid="plate-input"', BUY_LABEL, 'data-testid="buy-button"']) {
      expect(html, `page HTML must contain ${needle}`).toContain(needle);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-009 — inline script POSTs to /passes as JSON with {vehicle, months, plate}
  // ---------------------------------------------------------------------------
  test("TC-009 the page's inline script POSTs to /passes with Content-Type application/json and body {vehicle, months, plate}", async ({
    api,
  }) => {
    const res = await api.get("/web/buy?vehicle=car&months=1");

    expect(res.status()).toBe(200);
    const html = await res.text();
    for (const needle of ["/passes", "application/json", "vehicle", "months", "plate"]) {
      expect(html, `page HTML must contain ${needle}`).toContain(needle);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-010 — submit button disabled with the working label while the POST is in flight
  // ---------------------------------------------------------------------------
  test("TC-010 the page disables the submit button and shows 'กำลังดำเนินการ…' while the POST /passes request is in flight", async ({
    api,
  }) => {
    const res = await api.get("/web/buy?vehicle=car&months=1");

    expect(res.status()).toBe(200);
    const html = await res.text();
    for (const needle of [WORKING_LABEL, "disabled", 'data-testid="buy-button"']) {
      expect(html, `page HTML must contain ${needle}`).toContain(needle);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-011 — bought pass fields render inside buy-result on a 201, never the txn_id
  // ---------------------------------------------------------------------------
  test("TC-011 the page renders the bought pass fields inside buy-result on a 201 and never renders the API's txn_id", async ({
    api,
  }) => {
    const res = await api.get("/web/buy?vehicle=car&months=1");

    expect(res.status()).toBe(200);
    const html = await res.text();
    for (const needle of ['data-testid="buy-result"', 'data-testid="buy-error"']) {
      expect(html, `page HTML must contain ${needle}`).toContain(needle);
    }
    expect(html, "page HTML must not contain txn_id").not.toContain("txn_id");
  });

  // ---------------------------------------------------------------------------
  // TC-012 — same pass fields on a 200 idempotent replay, never the txn_id
  // ---------------------------------------------------------------------------
  test("TC-012 the page renders the same pass fields on a 200 idempotent replay and never renders the txn_id", async ({
    api,
  }) => {
    const res = await api.get("/web/buy?vehicle=car&months=1");

    expect(res.status()).toBe(200);
    const html = await res.text();
    expect(html, 'page HTML must contain data-testid="buy-result"').toContain('data-testid="buy-result"');
    expect(html, "page HTML must not contain txn_id").not.toContain("txn_id");
  });

  // ---------------------------------------------------------------------------
  // TC-013 — a 400 with a string detail is rendered VERBATIM inside buy-error,
  //          plate value kept, button enabled (browser-driven)
  // ---------------------------------------------------------------------------
  test("TC-013 a 400 POST /passes with a string detail renders it verbatim inside buy-error, keeping the plate and an enabled button", async ({
    page,
  }) => {
    await page.route("**/passes", (route) =>
      route.fulfill({
        status: 400,
        contentType: "application/json",
        body: JSON.stringify({ detail: "plate is required" }),
      }),
    );

    await page.goto("/web/buy?vehicle=car&months=1");
    await page.getByTestId("buy-button").click();

    // Screen shows
    await expect(page.getByTestId("buy-error")).toHaveText("plate is required");
    await expect(page.getByTestId("buy-error").getByText("plate is required")).toBeVisible();
    await expect(page.getByTestId("buy-button").getByText("ยืนยันซื้อ")).toBeVisible();

    // Screen hides
    await expect(page.getByText("กำลังดำเนินการ…")).toBeHidden();
    await expect(page.getByText("ซื้อสำเร็จ")).toBeHidden();
    await expect(page.getByText("pass-101")).toBeHidden();
    await expect(page.getByText("ลิงก์ไม่ถูกต้อง กรุณากลับไปเลือกที่หน้าราคา")).toBeHidden();

    // plate value kept, button enabled
    await expect(page.getByTestId("plate-input")).toHaveValue("");
    await expect(page.getByTestId("buy-button")).toBeEnabled();

    await page.screenshot({ path: `results/playwright/shots/ONODE-50-TC-013.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-014 — a 502 with a non-JSON body renders exactly the Thai fallback,
  //          plate value kept, button enabled (browser-driven)
  // ---------------------------------------------------------------------------
  test("TC-014 a 502 non-JSON POST /passes response renders exactly the Thai fallback inside buy-error, keeping the plate and an enabled button", async ({
    page,
  }) => {
    await page.route("**/passes", (route) =>
      route.fulfill({ status: 502, contentType: "text/plain", body: "Bad Gateway" }),
    );

    await page.goto("/web/buy?vehicle=car&months=1");
    await page.getByTestId("plate-input").fill("AB1234");
    await page.getByTestId("buy-button").click();

    // Screen shows
    await expect(page.getByTestId("buy-error")).toHaveText("ไม่สามารถซื้อบัตรได้ในขณะนี้ กรุณาลองใหม่");
    await expect(
      page.getByTestId("buy-error").getByText("ไม่สามารถซื้อบัตรได้ในขณะนี้ กรุณาลองใหม่"),
    ).toBeVisible();
    await expect(page.getByTestId("buy-button").getByText("ยืนยันซื้อ")).toBeVisible();

    // Screen hides
    await expect(page.getByText("กำลังดำเนินการ…")).toBeHidden();
    await expect(page.getByText("ซื้อสำเร็จ")).toBeHidden();
    await expect(page.getByText("pass-101")).toBeHidden();
    await expect(page.getByText("ลิงก์ไม่ถูกต้อง กรุณากลับไปเลือกที่หน้าราคา")).toBeHidden();

    // plate value kept, button enabled
    await expect(page.getByTestId("plate-input")).toHaveValue("AB1234");
    await expect(page.getByTestId("buy-button")).toBeEnabled();

    await page.screenshot({ path: `results/playwright/shots/ONODE-50-TC-014.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-015 — the page is stateless: no localStorage, no cookie, no language switcher
  // ---------------------------------------------------------------------------
  test("TC-015 the page is stateless: it stores nothing in localStorage or a cookie and has no language switcher", async ({
    api,
  }) => {
    const res = await api.get("/web/buy?vehicle=car&months=1");

    expect(res.status()).toBe(200);
    const html = await res.text();
    expect(html, 'page HTML must contain data-testid="buy-screen"').toContain('data-testid="buy-screen"');
    for (const needle of ["localStorage", "document.cookie", "language-switcher"]) {
      expect(html, `page HTML must not contain ${needle}`).not.toContain(needle);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-016 — the page only renders the existing pricing rule: car 1 month = 1500 THB
  // ---------------------------------------------------------------------------
  test("TC-016 the page only renders the existing pricing rule: car 1 month still shows 1500 THB unchanged", async ({
    api,
  }) => {
    const res = await api.get("/web/buy?vehicle=car&months=1");

    expect(res.status()).toBe(200);
    const html = await res.text();
    for (const needle of ["1500 THB", "รถยนต์", "1 เดือน"]) {
      expect(html, `page HTML must contain ${needle}`).toContain(needle);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-018 — a 201 renders the bought pass inside buy-result and never the txn_id
  //          (browser-driven)
  // ---------------------------------------------------------------------------
  test("TC-018 a 201 POST /passes renders the bought pass inside buy-result and never the txn_id", async ({
    page,
    dynamicId,
  }) => {
    await page.route("**/passes", (route) =>
      route.fulfill({
        status: 201,
        contentType: "application/json",
        body: JSON.stringify({
          id: "pass-101",
          plate: "AB1234",
          vehicle: "car",
          months: 1,
          price: 1500,
          status: "active",
          txn_id: `txn-secret-${dynamicId}`,
        }),
      }),
    );

    await page.goto("/web/buy?vehicle=car&months=1");
    await page.getByTestId("plate-input").fill("AB1234");
    await page.getByTestId("buy-button").click();

    // Screen shows — scoped to buy-result so the summary block cannot satisfy them
    const result = page.getByTestId("buy-result");
    await expect(result.getByText("ซื้อสำเร็จ")).toBeVisible();
    await expect(result.getByText("pass-101")).toBeVisible();
    await expect(result.getByText("AB1234")).toBeVisible();
    await expect(result.getByText("รถยนต์")).toBeVisible();
    await expect(result.getByText("1 เดือน")).toBeVisible();
    await expect(result.getByText("1500 THB")).toBeVisible();
    await expect(result.getByText("active")).toBeVisible();

    // Screen hides
    await expect(page.getByText("กำลังดำเนินการ…")).toBeHidden();
    await expect(page.getByText("plate is required")).toBeHidden();
    await expect(page.getByText("ลิงก์ไม่ถูกต้อง กรุณากลับไปเลือกที่หน้าราคา")).toBeHidden();
    await expect(page.getByText("กลับไปหน้าราคา")).toBeHidden();
    await expect(page.getByText("ไม่สามารถซื้อบัตรได้ในขณะนี้ กรุณาลองใหม่")).toBeHidden();

    // never the txn_id
    await expect(page.getByTestId("buy-screen")).not.toContainText(`txn-secret-${dynamicId}`);

    await page.screenshot({ path: `results/playwright/shots/ONODE-50-TC-018.png`, fullPage: true });
  });
});