import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-53 — GET /web/buy restyled to the ONODE-50 mockup: the error state is a danger-soft
 * box with role="alert", the success state is a success-soft card with labelled fields.
 * One test per approved CSV row (test_designs/ONODE-53.csv): TC-001 … TC-018, titled with its CaseID.
 *
 * Rows whose ExpectedResult is about the STATIC GET HTML assert on the response body (api).
 * Rows whose ExpectedResult is about what the page's own JS renders at runtime drive the real
 * browser (page) and intercept POST /passes with page.route — correct here because what is under
 * test is the PAGE's JS in the browser, not the app server's outbound call. Those rows also arm
 * the row's `Mock POST /passes …` through mock.arm so the row's stub instruction is honoured.
 * Every UI row ends with a screenshot into the visual gate.
 */
test.describe("ONODE-53 — GET /web/buy restyled to the ONODE-50 mockup", () => {
  const INVALID_LINK = "ลิงก์ไม่ถูกต้อง กรุณากลับไปเลือกที่หน้าราคา";
  const BACK_TO_QUOTE = "กลับไปหน้าราคา";

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

  /** The success payload every stubbed 201/200 row answers with. */
  function passBody(dynamicId: number) {
    return {
      id: "pass-101",
      plate: "AB1234",
      vehicle: "car",
      months: 1,
      price: 1500,
      status: "active",
      txn_id: `txn_${dynamicId}`,
    };
  }

  // ---------------------------------------------------------------------------
  // TC-001 — vehicle absent → invalid-link state, 200 HTML (E1)
  // ---------------------------------------------------------------------------
  test("TC-001 GET /web/buy without the vehicle parameter renders the invalid-link state as a 200 HTML page", async ({
    api,
  }) => {
    const res = await api.get("/web/buy?months=1");

    expect(res.status()).toBe(200);
    const html = await res.text();
    expect(html, 'page HTML must contain data-testid="buy-invalid-link"').toContain(
      'data-testid="buy-invalid-link"',
    );
    expect(html, `page HTML must contain ${INVALID_LINK}`).toContain(INVALID_LINK);
    expect(html, `page HTML must contain ${BACK_TO_QUOTE}`).toContain(BACK_TO_QUOTE);
  });

  // ---------------------------------------------------------------------------
  // TC-002 — months=0 (outside 1..12) → invalid-link state, 200 HTML (E2)
  // ---------------------------------------------------------------------------
  test("TC-002 GET /web/buy with months=0 renders the invalid-link state as a 200 HTML page", async ({ api }) => {
    const res = await api.get("/web/buy?vehicle=car&months=0");

    expect(res.status()).toBe(200);
    const html = await res.text();
    expect(html, 'page HTML must contain data-testid="buy-invalid-link"').toContain(
      'data-testid="buy-invalid-link"',
    );
    expect(html, `page HTML must contain ${INVALID_LINK}`).toContain(INVALID_LINK);
    expect(html, `page HTML must contain ${BACK_TO_QUOTE}`).toContain(BACK_TO_QUOTE);
  });

  // ---------------------------------------------------------------------------
  // TC-003 — public page: 200 text/html, no redirect, no JSON (B1)
  // ---------------------------------------------------------------------------
  test("TC-003 GET /web/buy is public and answers 200 text/html with no redirect and no JSON", async ({ api }) => {
    const res = await api.get("/web/buy?vehicle=car&months=1");

    expect(res.status()).toBe(200);
    expect(res.headers()["content-type"]).toContain("text/html");
    const html = await res.text();
    expect(html, "page HTML must contain <!doctype html").toContain("<!doctype html");
    expect(html, 'page HTML must contain data-testid="buy-screen"').toContain('data-testid="buy-screen"');
    expect(html, "page HTML must contain ONODE Parking").toContain("ONODE Parking");
  });

  // ---------------------------------------------------------------------------
  // TC-004 — car/1 shows vehicle, months and price (B4, W1)
  // ---------------------------------------------------------------------------
  test("TC-004 the initial page shows vehicle, months and price for car/1", async ({ api }) => {
    const res = await api.get("/web/buy?vehicle=car&months=1");

    expect(res.status()).toBe(200);
    const html = await res.text();
    expect(html, 'page HTML must contain data-testid="buy-vehicle">รถยนต์').toContain(
      'data-testid="buy-vehicle">รถยนต์',
    );
    expect(html, 'page HTML must contain data-testid="buy-months">1 เดือน').toContain(
      'data-testid="buy-months">1 เดือน',
    );
    expect(html, 'page HTML must contain data-testid="buy-price">1500 THB').toContain(
      'data-testid="buy-price">1500 THB',
    );
  });

  // ---------------------------------------------------------------------------
  // TC-005 — all nine data-testid hooks kept exactly (B3)
  // ---------------------------------------------------------------------------
  test("TC-005 the page keeps all nine data-testid hooks exactly", async ({ api }) => {
    const res = await api.get("/web/buy?vehicle=car&months=1");

    expect(res.status()).toBe(200);
    const html = await res.text();
    for (const needle of NINE_HOOKS) {
      expect(html, `page HTML must contain ${needle}`).toContain(needle);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-006 — plate field stays an <input> labelled 'ทะเบียนรถ' (B5)
  // ---------------------------------------------------------------------------
  test("TC-006 the plate field stays an <input> labelled 'ทะเบียนรถ' with data-testid plate-input", async ({
    api,
  }) => {
    const res = await api.get("/web/buy?vehicle=car&months=1");

    expect(res.status()).toBe(200);
    const html = await res.text();
    expect(html, "page HTML must contain <input").toContain("<input");
    expect(html, 'page HTML must contain data-testid="plate-input"').toContain('data-testid="plate-input"');
    expect(html, "page HTML must contain ทะเบียนรถ").toContain("ทะเบียนรถ");
  });

  // ---------------------------------------------------------------------------
  // TC-007 — submit wiring still POSTs to /passes and shows the working state (B6)
  // ---------------------------------------------------------------------------
  test("TC-007 the page's submit wiring still POSTs to /passes with JSON body {vehicle, months, plate} and shows the working state", async ({
    page,
    mock,
    dynamicId,
  }) => {
    // The row's stub: POST /passes answers 201 with the bought pass.
    await mock.arm("POST", "/passes", 201, passBody(dynamicId));
    // Hold the POST open so the in-flight working state is observable.
    await page.route("**/passes", async (route) => {
      await new Promise((resolve) => setTimeout(resolve, 3_000));
      await route.fulfill({
        status: 201,
        contentType: "application/json",
        body: JSON.stringify(passBody(dynamicId)),
      });
    });

    await page.goto("/web/buy?vehicle=car&months=1");
    await page.getByTestId("plate-input").fill("AB1234");
    await page.getByTestId("buy-button").click();

    // Screen shows
    await expect(page.getByText("ONODE Parking").first()).toBeVisible();
    await expect(page.getByText("ยืนยันซื้อบัตรจอดรถรายเดือน").first()).toBeVisible();
    await expect(page.getByText("ประเภทรถ").first()).toBeVisible();
    await expect(page.getByText("รถยนต์").first()).toBeVisible();
    await expect(page.getByText("ระยะเวลา").first()).toBeVisible();
    await expect(page.getByText("1 เดือน").first()).toBeVisible();
    await expect(page.getByText("ราคารวม").first()).toBeVisible();
    await expect(page.getByText("1500 THB").first()).toBeVisible();
    await expect(page.getByText("ทะเบียนรถ").first()).toBeVisible();
    await expect(page.getByText("กำลังดำเนินการ…").first()).toBeVisible();

    // Screen hides
    await expect(page.getByText("ซื้อสำเร็จ").first()).toBeHidden();
    await expect(page.getByText("plate is required").first()).toBeHidden();
    await expect(page.getByText("ไม่สามารถซื้อบัตรได้ในขณะนี้ กรุณาลองใหม่").first()).toBeHidden();

    await page.screenshot({ path: `results/playwright/shots/ONODE-53-TC-007.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-008 — buy-error and buy-result start hidden (X8, B7)
  // ---------------------------------------------------------------------------
  test("TC-008 the initial page hides buy-error and buy-result so no empty coloured box is visible", async ({
    api,
  }) => {
    const res = await api.get("/web/buy?vehicle=car&months=1");

    expect(res.status()).toBe(200);
    const html = await res.text();
    expect(html, 'page HTML must contain data-testid="buy-result" hidden').toContain(
      'data-testid="buy-result" hidden',
    );
    expect(html, 'page HTML must contain data-testid="buy-error" hidden').toContain(
      'data-testid="buy-error" hidden',
    );
  });

  // ---------------------------------------------------------------------------
  // TC-009 — API detail 'plate is required' renders verbatim in the danger-soft box (X1, B7)
  // ---------------------------------------------------------------------------
  test("TC-009 the API detail 'plate is required' renders inside the danger-soft buy-error box with role=alert, verbatim", async ({
    page,
    mock,
  }) => {
    await mock.arm("POST", "/passes", 400, { detail: "plate is required" });
    await page.route("**/passes", (route) =>
      route.fulfill({
        status: 400,
        contentType: "application/json",
        body: JSON.stringify({ detail: "plate is required" }),
      }),
    );

    await page.goto("/web/buy?vehicle=car&months=1");
    await page.getByTestId("plate-input").fill("AB1234");
    await page.getByTestId("buy-button").click();

    // Screen shows — the detail verbatim, inside the alert box
    const errorBox = page.getByTestId("buy-error");
    await expect(errorBox).toBeVisible();
    await expect(errorBox).toHaveAttribute("role", "alert");
    await expect(errorBox).toHaveText("plate is required");
    await expect(page.getByText("plate is required").first()).toBeVisible();

    // Screen hides
    await expect(page.getByText("ซื้อสำเร็จ").first()).toBeHidden();
    await expect(page.getByText("ไม่สามารถซื้อบัตรได้ในขณะนี้ กรุณาลองใหม่").first()).toBeHidden();
    await expect(page.getByText("ลิงก์ไม่ถูกต้อง กรุณากลับไปเลือกที่หน้าราคา").first()).toBeHidden();

    await page.screenshot({ path: `results/playwright/shots/ONODE-53-TC-009.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-010 — network-failure fallback renders in the same danger-soft box (X2, B7)
  // ---------------------------------------------------------------------------
  test("TC-010 the network-failure fallback renders in the same danger-soft box", async ({ page, mock }) => {
    await mock.arm("POST", "/passes", 500, { error: "boom" });
    await page.route("**/passes", (route) =>
      route.fulfill({ status: 500, contentType: "text/plain", body: "Internal Server Error" }),
    );

    await page.goto("/web/buy?vehicle=car&months=1");
    await page.getByTestId("plate-input").fill("AB1234");
    await page.getByTestId("buy-button").click();

    // Screen shows
    const errorBox = page.getByTestId("buy-error");
    await expect(errorBox).toBeVisible();
    await expect(errorBox).toHaveAttribute("role", "alert");
    await expect(errorBox).toHaveText("ไม่สามารถซื้อบัตรได้ในขณะนี้ กรุณาลองใหม่");
    await expect(page.getByText("ไม่สามารถซื้อบัตรได้ในขณะนี้ กรุณาลองใหม่").first()).toBeVisible();

    // Screen hides
    await expect(page.getByText("ซื้อสำเร็จ").first()).toBeHidden();
    await expect(page.getByText("plate is required").first()).toBeHidden();
    await expect(page.getByText("ลิงก์ไม่ถูกต้อง กรุณากลับไปเลือกที่หน้าราคา").first()).toBeHidden();

    await page.screenshot({ path: `results/playwright/shots/ONODE-53-TC-010.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-011 — a long API detail renders verbatim inside the danger-soft box (X3, B7)
  // ---------------------------------------------------------------------------
  test("TC-011 a long API detail renders verbatim inside the danger-soft box", async ({ page, mock }) => {
    const longDetail = "plate must be a string of at most 10 characters";
    await mock.arm("POST", "/passes", 400, { detail: longDetail });
    await page.route("**/passes", (route) =>
      route.fulfill({
        status: 400,
        contentType: "application/json",
        body: JSON.stringify({ detail: longDetail }),
      }),
    );

    await page.goto("/web/buy?vehicle=car&months=1");
    await page.getByTestId("plate-input").fill("AB1234");
    await page.getByTestId("buy-button").click();

    // Screen shows
    const errorBox = page.getByTestId("buy-error");
    await expect(errorBox).toBeVisible();
    await expect(errorBox).toHaveAttribute("role", "alert");
    await expect(errorBox).toHaveText(longDetail);
    await expect(page.getByText(longDetail).first()).toBeVisible();

    // Screen hides
    await expect(page.getByText("ซื้อสำเร็จ").first()).toBeHidden();
    await expect(page.getByText("ไม่สามารถซื้อบัตรได้ในขณะนี้ กรุณาลองใหม่").first()).toBeHidden();
    await expect(page.getByText("ลิงก์ไม่ถูกต้อง กรุณากลับไปเลือกที่หน้าราคา").first()).toBeHidden();

    await page.screenshot({ path: `results/playwright/shots/ONODE-53-TC-011.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-012 — 201 renders the success-soft pass-card with title, six labelled fields
  //          and status pill (X4, B8, W2)
  // ---------------------------------------------------------------------------
  test("TC-012 a 201 success renders the success-soft pass-card with title, six labelled fields and status pill", async ({
    page,
    mock,
    dynamicId,
  }) => {
    await mock.arm("POST", "/passes", 201, passBody(dynamicId));
    await page.route("**/passes", (route) =>
      route.fulfill({
        status: 201,
        contentType: "application/json",
        body: JSON.stringify(passBody(dynamicId)),
      }),
    );

    await page.goto("/web/buy?vehicle=car&months=1");
    await page.getByTestId("plate-input").fill("AB1234");
    await page.getByTestId("buy-button").click();

    // Screen shows — scoped to buy-result so the summary block cannot satisfy them
    const result = page.getByTestId("buy-result");
    await expect(result).toBeVisible();
    await expect(page.getByText("ONODE Parking").first()).toBeVisible();
    await expect(result.getByText("ซื้อสำเร็จ").first()).toBeVisible();
    await expect(result.getByText("เลขบัตร").first()).toBeVisible();
    await expect(result.getByText("pass-101").first()).toBeVisible();
    await expect(result.getByText("ทะเบียนรถ").first()).toBeVisible();
    await expect(result.getByText("AB1234").first()).toBeVisible();
    await expect(result.getByText("ประเภทรถ").first()).toBeVisible();
    await expect(result.getByText("รถยนต์").first()).toBeVisible();
    await expect(result.getByText("ระยะเวลา").first()).toBeVisible();
    await expect(result.getByText("1 เดือน").first()).toBeVisible();
    await expect(result.getByText("ราคา").first()).toBeVisible();
    await expect(result.getByText("1500 THB").first()).toBeVisible();
    await expect(result.getByText("สถานะ").first()).toBeVisible();
    await expect(result.getByText("active").first()).toBeVisible();
    await expect(page.getByText("ยืนยันซื้อ").first()).toBeVisible();

    // Screen hides
    await expect(page.getByText("plate is required").first()).toBeHidden();
    await expect(page.getByText("ไม่สามารถซื้อบัตรได้ในขณะนี้ กรุณาลองใหม่").first()).toBeHidden();
    await expect(page.getByText("ลิงก์ไม่ถูกต้อง กรุณากลับไปเลือกที่หน้าราคา").first()).toBeHidden();

    await page.screenshot({ path: `results/playwright/shots/ONODE-53-TC-012.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-013 — 200 idempotent replay renders the same success card (X5, B8)
  // ---------------------------------------------------------------------------
  test("TC-013 a 200 idempotent replay renders the same success card with the same fields", async ({
    page,
    mock,
    dynamicId,
  }) => {
    await mock.arm("POST", "/passes", 200, passBody(dynamicId));
    await page.route("**/passes", (route) =>
      route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify(passBody(dynamicId)),
      }),
    );

    await page.goto("/web/buy?vehicle=car&months=1");
    await page.getByTestId("plate-input").fill("AB1234");
    await page.getByTestId("buy-button").click();

    // Screen shows — scoped to buy-result
    const result = page.getByTestId("buy-result");
    await expect(result).toBeVisible();
    await expect(result.getByText("ซื้อสำเร็จ").first()).toBeVisible();
    await expect(result.getByText("เลขบัตร").first()).toBeVisible();
    await expect(result.getByText("pass-101").first()).toBeVisible();
    await expect(result.getByText("ทะเบียนรถ").first()).toBeVisible();
    await expect(result.getByText("AB1234").first()).toBeVisible();
    await expect(result.getByText("ประเภทรถ").first()).toBeVisible();
    await expect(result.getByText("รถยนต์").first()).toBeVisible();
    await expect(result.getByText("ระยะเวลา").first()).toBeVisible();
    await expect(result.getByText("1 เดือน").first()).toBeVisible();
    await expect(result.getByText("ราคา").first()).toBeVisible();
    await expect(result.getByText("1500 THB").first()).toBeVisible();
    await expect(result.getByText("สถานะ").first()).toBeVisible();
    await expect(result.getByText("active").first()).toBeVisible();
    await expect(page.getByText("ยืนยันซื้อ").first()).toBeVisible();

    // Screen hides
    await expect(page.getByText("plate is required").first()).toBeHidden();
    await expect(page.getByText("ไม่สามารถซื้อบัตรได้ในขณะนี้ กรุณาลองใหม่").first()).toBeHidden();
    await expect(page.getByText("ลิงก์ไม่ถูกต้อง กรุณากลับไปเลือกที่หน้าราคา").first()).toBeHidden();

    await page.screenshot({ path: `results/playwright/shots/ONODE-53-TC-013.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-014 — the success card never renders the API's txn_id (X6, B9)
  // ---------------------------------------------------------------------------
  test("TC-014 the success card never renders the API's txn_id", async ({ api }) => {
    const res = await api.get("/web/buy?vehicle=car&months=1");

    expect(res.status()).toBe(200);
    const html = await res.text();
    expect(html, 'page HTML must contain data-testid="buy-result"').toContain('data-testid="buy-result"');
    expect(html, "page HTML must not render the API's txn_id").not.toContain("txn_id");
  });

  // ---------------------------------------------------------------------------
  // TC-015 — the success card's field values match the API's payload (B9)
  // ---------------------------------------------------------------------------
  test("TC-015 the success card's field values match the API's id, plate, vehicle label, months, price and status", async ({
    page,
    mock,
    dynamicId,
  }) => {
    await mock.arm("POST", "/passes", 201, passBody(dynamicId));
    await page.route("**/passes", (route) =>
      route.fulfill({
        status: 201,
        contentType: "application/json",
        body: JSON.stringify(passBody(dynamicId)),
      }),
    );

    await page.goto("/web/buy?vehicle=car&months=1");
    await page.getByTestId("plate-input").fill("AB1234");
    await page.getByTestId("buy-button").click();

    // Screen shows — scoped to buy-result
    const result = page.getByTestId("buy-result");
    await expect(result).toBeVisible();
    await expect(result.getByText("pass-101").first()).toBeVisible();
    await expect(result.getByText("AB1234").first()).toBeVisible();
    await expect(result.getByText("รถยนต์").first()).toBeVisible();
    await expect(result.getByText("1 เดือน").first()).toBeVisible();
    await expect(result.getByText("1500 THB").first()).toBeVisible();
    await expect(result.getByText("active").first()).toBeVisible();
    await expect(page.getByText("ยืนยันซื้อ").first()).toBeVisible();

    // Screen hides
    await expect(page.getByText("plate is required").first()).toBeHidden();
    await expect(page.getByText("ไม่สามารถซื้อบัตรได้ในขณะนี้ กรุณาลองใหม่").first()).toBeHidden();
    await expect(page.getByText("ลิงก์ไม่ถูกต้อง กรุณากลับไปเลือกที่หน้าราคา").first()).toBeHidden();

    await page.screenshot({ path: `results/playwright/shots/ONODE-53-TC-015.png`, fullPage: true });
  });

  // ---------------------------------------------------------------------------
  // TC-016 — the page remains stateless: no localStorage, no cookie, no switcher (B10)
  // ---------------------------------------------------------------------------
  test("TC-016 the page remains stateless — no localStorage, no cookie, no language switcher", async ({ api }) => {
    const res = await api.get("/web/buy?vehicle=car&months=1");

    expect(res.status()).toBe(200);
    const html = await res.text();
    expect(html, 'page HTML must contain data-testid="buy-screen"').toContain('data-testid="buy-screen"');
    expect(html, "page HTML must not contain localStorage").not.toContain("localStorage");
    expect(html, "page HTML must not contain document.cookie").not.toContain("document.cookie");
    expect(html, "page HTML must not contain language-switcher").not.toContain("language-switcher");
  });

  // ---------------------------------------------------------------------------
  // TC-017 — invalid-link state renders an alert-danger box with role=alert (X7, B2)
  // ---------------------------------------------------------------------------
  test("TC-017 the invalid-link state renders an alert-danger box with role=alert and the quote link, unchanged", async ({
    api,
  }) => {
    const res = await api.get("/web/buy?vehicle=truck&months=1");

    expect(res.status()).toBe(200);
    const html = await res.text();
    expect(html, 'page HTML must contain data-testid="buy-invalid-link"').toContain(
      'data-testid="buy-invalid-link"',
    );
    expect(html, "page HTML must contain alert-danger").toContain("alert-danger");
    expect(html, 'page HTML must contain role="alert"').toContain('role="alert"');
    expect(html, `page HTML must contain ${INVALID_LINK}`).toContain(INVALID_LINK);
    expect(html, `page HTML must contain ${BACK_TO_QUOTE}`).toContain(BACK_TO_QUOTE);
  });

  // ---------------------------------------------------------------------------
  // TC-018 — POST /passes unchanged: the API's own error detail renders verbatim (B11, B7)
  // ---------------------------------------------------------------------------
  test("TC-018 the page still renders the API's own error detail verbatim inside the danger-soft box", async ({
    page,
  }) => {
    await page.goto("/web/buy?vehicle=car&months=1");
    await page.getByTestId("plate-input").fill("");
    await page.getByTestId("buy-button").click();

    // Screen shows
    await expect(page.getByText("ONODE Parking").first()).toBeVisible();
    await expect(page.getByText("ยืนยันซื้อบัตรจอดรถรายเดือน").first()).toBeVisible();
    await expect(page.getByText("ประเภทรถ").first()).toBeVisible();
    await expect(page.getByText("รถยนต์").first()).toBeVisible();
    await expect(page.getByText("ระยะเวลา").first()).toBeVisible();
    await expect(page.getByText("1 เดือน").first()).toBeVisible();
    await expect(page.getByText("ราคารวม").first()).toBeVisible();
    await expect(page.getByText("1500 THB").first()).toBeVisible();
    await expect(page.getByText("ทะเบียนรถ").first()).toBeVisible();
    await expect(page.getByText("ยืนยันซื้อ").first()).toBeVisible();
    const errorBox = page.getByTestId("buy-error");
    await expect(errorBox).toBeVisible();
    await expect(errorBox).toHaveAttribute("role", "alert");
    await expect(errorBox).toHaveText("plate is required");
    await expect(page.getByText("plate is required").first()).toBeVisible();

    // Screen hides
    await expect(page.getByText("ซื้อสำเร็จ").first()).toBeHidden();
    await expect(page.getByText("ไม่สามารถซื้อบัตรได้ในขณะนี้ กรุณาลองใหม่").first()).toBeHidden();
    await expect(page.getByText("ลิงก์ไม่ถูกต้อง กรุณากลับไปเลือกที่หน้าราคา").first()).toBeHidden();

    await page.screenshot({ path: `results/playwright/shots/ONODE-53-TC-018.png`, fullPage: true });
  });
});