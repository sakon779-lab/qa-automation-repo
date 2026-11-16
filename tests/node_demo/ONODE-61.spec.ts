import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-61 — POST /passes must parse every `application/*+json` media type (the +json suffix
 * parser is registered app-wide), while every already-delivered answer stays byte-identical.
 *
 * One test per approved CSV row (test_designs/ONODE-61.csv): TC-001 … TC-027 (no TC-024 row).
 *
 * Malformed / exact-byte bodies are sent as Buffer.from(...): Playwright JSON-ENCODES a string
 * under a JSON Content-Type, so `{bad` would leave as the valid JSON `"{bad"` and the server
 * would answer a different error (the ONODE-46 trap named in the role card).
 *
 * The gateway is stubbed through `mock.arm` at the path the deployed app actually calls
 * (`/charge`, as the delivered ONODE-16/23/46/60 suites do), scoped to this test's X-Request-Id
 * which `api` sends and the app forwards. Every test cleans up its own rows in a finally block
 * so the fully-parallel suite never collides.
 */
const JSON_CT = "application/json";
const VND_JSON_CT = "application/vnd.api+json";
const GATEWAY_PATH = "/charge";

/** A JSON body of exactly `total` bytes shaped {vehicle, months, plate, pad}. */
function jsonBodyOfSize(total: number, vehicle: string): Buffer {
  const head = `{"vehicle": "${vehicle}", "months": 1, "plate": "AB1", "pad": "`;
  const tail = `"}`;
  const padLen = total - Buffer.byteLength(head) - Buffer.byteLength(tail);
  if (padLen < 0) throw new Error(`jsonBodyOfSize: ${total} bytes is too small for the envelope`);
  return Buffer.from(head + "x".repeat(padLen) + tail, "utf8");
}

test.describe("ONODE-61 — application/*+json bodies are parsed by POST /passes", () => {
  // ---------------------------------------------------------------------------
  // TC-001 — E1/B1/B4: vnd.api+json with malformed body '{bad' → 400 valid JSON (was 415)
  // ---------------------------------------------------------------------------
  test("TC-001 application/vnd.api+json with a malformed body returns 400 request body must be valid JSON", async ({
    api,
  }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": VND_JSON_CT },
      data: Buffer.from("{bad", "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "request body must be valid JSON" });
  });

  // ---------------------------------------------------------------------------
  // TC-002 — E1/B2: ld+json with a body truncated mid-object → 400 valid JSON
  // ---------------------------------------------------------------------------
  test("TC-002 application/ld+json with a truncated body returns 400 request body must be valid JSON", async ({
    api,
  }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": "application/ld+json" },
      data: Buffer.from('{"vehicle": "car", "months": 1, "plate": "AB1"', "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "request body must be valid JSON" });
  });

  // ---------------------------------------------------------------------------
  // TC-003 — E2/B6: vnd.api+json body parsing to the literal 42 reaches the route → 400
  // ---------------------------------------------------------------------------
  test("TC-003 application/vnd.api+json with a non-object body reaches the route and returns 400 vehicle is required", async ({
    api,
  }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": VND_JSON_CT },
      data: Buffer.from("42", "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "vehicle is required" });
  });

  // ---------------------------------------------------------------------------
  // TC-004 — E3/B6: vnd.api+json with '{}' reaches the route → 400 vehicle is required (was 415)
  // ---------------------------------------------------------------------------
  test("TC-004 application/vnd.api+json with an empty JSON object returns 400 vehicle is required", async ({
    api,
  }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": VND_JSON_CT },
      data: Buffer.from("{}", "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "vehicle is required" });
  });

  // ---------------------------------------------------------------------------
  // TC-005 — E4/B5: vnd.api+json body over the 1048576-byte limit → 413
  // ---------------------------------------------------------------------------
  test("TC-005 application/vnd.api+json with a body over 1048576 bytes returns 413 request body too large", async ({
    api,
  }) => {
    const body = jsonBodyOfSize(1_048_577, "car");
    expect(body.byteLength).toBe(1_048_577);

    const res = await api.post("/passes", {
      headers: { "Content-Type": VND_JSON_CT },
      data: body,
    });

    expect(res.status()).toBe(413);
    expect(await res.json()).toMatchObject({ detail: "request body too large" });
  });

  // ---------------------------------------------------------------------------
  // TC-006 — E5/B2: application/xml is not parsed → 415 unsupported content type
  // ---------------------------------------------------------------------------
  test("TC-006 application/xml still returns 415 unsupported content type", async ({ api }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": "application/xml" },
      data: Buffer.from("<pass/>", "utf8"),
    });

    expect(res.status()).toBe(415);
    expect(await res.json()).toMatchObject({ detail: "unsupported content type" });
  });

  // ---------------------------------------------------------------------------
  // TC-007 — E5/B2: application/jsonx does NOT end with '+json' → 415
  // ---------------------------------------------------------------------------
  test("TC-007 application/jsonx still returns 415 unsupported content type", async ({ api }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": "application/jsonx" },
      data: Buffer.from('{"vehicle": "car", "months": 1, "plate": "AB1"}', "utf8"),
    });

    expect(res.status()).toBe(415);
    expect(await res.json()).toMatchObject({ detail: "unsupported content type" });
  });

  // ---------------------------------------------------------------------------
  // TC-008 — E6/B4: application/json malformed body → 400 valid JSON (ONODE-46 regression)
  // ---------------------------------------------------------------------------
  test("TC-008 application/json with a malformed body still returns 400 request body must be valid JSON", async ({
    api,
  }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": JSON_CT },
      data: Buffer.from("{bad", "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "request body must be valid JSON" });
  });

  // ---------------------------------------------------------------------------
  // TC-009 — E7/B6: application/json missing vehicle → 400 vehicle is required
  // ---------------------------------------------------------------------------
  test("TC-009 application/json with the vehicle key missing returns 400 vehicle is required", async ({ api }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": JSON_CT },
      data: Buffer.from('{"months": 3, "plate": "AB1"}', "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "vehicle is required" });
  });

  // ---------------------------------------------------------------------------
  // TC-010 — E8: application/json vehicle 'truck' → 400 vehicle must be car or motorcycle
  // ---------------------------------------------------------------------------
  test("TC-010 application/json with vehicle truck returns 400 vehicle must be car or motorcycle", async ({
    api,
  }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": JSON_CT },
      data: Buffer.from('{"vehicle": "truck", "months": 3, "plate": "AB1"}', "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "vehicle must be car or motorcycle" });
  });

  // ---------------------------------------------------------------------------
  // TC-011 — E9: application/json months missing → 400 months is required
  // ---------------------------------------------------------------------------
  test("TC-011 application/json with months missing returns 400 months is required", async ({ api }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": JSON_CT },
      data: Buffer.from('{"vehicle": "car", "plate": "AB1"}', "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "months is required" });
  });

  // ---------------------------------------------------------------------------
  // TC-012 — E10: application/json months 13 → 400 months must be an integer from 1 to 12
  // ---------------------------------------------------------------------------
  test("TC-012 application/json with months 13 returns 400 months must be an integer from 1 to 12", async ({
    api,
  }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": JSON_CT },
      data: Buffer.from('{"vehicle": "car", "months": 13, "plate": "AB1"}', "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "months must be an integer from 1 to 12" });
  });

  // ---------------------------------------------------------------------------
  // TC-013 — E11: application/json plate missing → 400 plate is required
  // ---------------------------------------------------------------------------
  test("TC-013 application/json with plate missing returns 400 plate is required", async ({ api }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": JSON_CT },
      data: Buffer.from('{"vehicle": "car", "months": 3}', "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "plate is required" });
  });

  // ---------------------------------------------------------------------------
  // TC-014 — E12: application/json plate longer than 10 chars → 400
  // ---------------------------------------------------------------------------
  test("TC-014 application/json with an over-long plate returns 400 plate must be a string of at most 10 characters", async ({
    api,
  }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": JSON_CT },
      data: Buffer.from('{"vehicle": "car", "months": 3, "plate": "ABCDEFGHIJK"}', "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "plate must be a string of at most 10 characters" });
  });
});

test.describe("ONODE-61 — gateway outcomes, stateful writes and the app-wide +json parser", () => {
  // ---------------------------------------------------------------------------
  // TC-015 — E13: application/json + DECLINED gateway → 402, no passes row
  // ---------------------------------------------------------------------------
  test("TC-015 application/json with a DECLINED gateway returns 402 payment declined and writes no pass", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", GATEWAY_PATH, 200, { status: "DECLINED" });

      const res = await api.post("/passes", {
        headers: { "Content-Type": JSON_CT },
        data: Buffer.from(JSON.stringify({ vehicle: "car", months: 3, plate }), "utf8"),
      });

      expect(res.status()).toBe(402);
      expect(await res.json()).toMatchObject({ detail: "payment declined" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE reference = '${plate}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-016 — E14: application/json + gateway 500 → 502, no passes row
  // ---------------------------------------------------------------------------
  test("TC-016 application/json with a gateway 500 returns 502 payment gateway unavailable and writes no pass", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", GATEWAY_PATH, 500, { detail: "boom" });

      const res = await api.post("/passes", {
        headers: { "Content-Type": JSON_CT },
        data: Buffer.from(JSON.stringify({ vehicle: "car", months: 3, plate }), "utf8"),
      });

      expect(res.status()).toBe(502);
      expect(await res.json()).toMatchObject({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE reference = '${plate}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-017 — E15: application/json + SUCCESS with an empty txn_id → 502, no passes row
  // ---------------------------------------------------------------------------
  test("TC-017 application/json with a SUCCESS gateway and an empty txn_id returns 502 and writes no pass", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", GATEWAY_PATH, 200, { status: "SUCCESS", txn_id: "" });

      const res = await api.post("/passes", {
        headers: { "Content-Type": JSON_CT },
        data: Buffer.from(JSON.stringify({ vehicle: "car", months: 3, plate }), "utf8"),
      });

      expect(res.status()).toBe(502);
      expect(await res.json()).toMatchObject({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE reference = '${plate}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-018 — E16: application/json + gateway exceeding the timeout → 502, no passes row
  // ---------------------------------------------------------------------------
  test("TC-018 application/json with a gateway timeout returns 502 payment gateway unavailable and writes no pass", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm(
        "POST",
        GATEWAY_PATH,
        200,
        { status: "SUCCESS", txn_id: `txn-${dynamicId}` },
        { delayMs: 30_000 },
      );

      const res = await api.post("/passes", {
        headers: { "Content-Type": JSON_CT },
        data: Buffer.from(JSON.stringify({ vehicle: "car", months: 3, plate }), "utf8"),
      });

      expect(res.status()).toBe(502);
      expect(await res.json()).toMatchObject({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE reference = '${plate}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-019 — B6/W1: vnd.api+json valid body + SUCCESS gateway → 201, plate trimmed, THB, ACTIVE
  // ---------------------------------------------------------------------------
  test("TC-019 application/vnd.api+json with a valid body returns 201 with the trimmed plate and an ACTIVE pass", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `AB${dynamicId}`.slice(0, 10);
    const txnId = `txn_${dynamicId}`;
    try {
      await mock.arm("POST", GATEWAY_PATH, 200, { status: "SUCCESS", txn_id: txnId });
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);

      const res = await api.post("/passes", {
        headers: { "Content-Type": VND_JSON_CT },
        data: Buffer.from(
          JSON.stringify({ vehicle: "car", months: 3, plate: `  ${plate}  ` }),
          "utf8",
        ),
      });

      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({
        vehicle: "car",
        months: 3,
        plate,
        currency: "THB",
        txn_id: txnId,
        status: "ACTIVE",
      });

      expect(
        await db.value(
          `SELECT count(*) FROM passes WHERE plate = '${plate}' AND txn_id = '${txnId}' AND status = 'ACTIVE'`,
        ),
      ).toBe(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-020 — B3/W2: 'application/vnd.api+json; charset=utf-8' → 201 (charset stripped first)
  // ---------------------------------------------------------------------------
  test("TC-020 application/vnd.api+json with a charset parameter returns 201 for a motorcycle pass", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `XY${dynamicId}`.slice(0, 10);
    const txnId = `txn_${dynamicId}`;
    try {
      await mock.arm("POST", GATEWAY_PATH, 200, { status: "SUCCESS", txn_id: txnId });
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);

      const res = await api.post("/passes", {
        headers: { "Content-Type": "application/vnd.api+json; charset=utf-8" },
        data: Buffer.from(
          JSON.stringify({ vehicle: "motorcycle", months: 1, plate }),
          "utf8",
        ),
      });

      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({
        vehicle: "motorcycle",
        months: 1,
        plate,
        currency: "THB",
        txn_id: txnId,
        status: "ACTIVE",
      });

      expect(
        await db.value(
          `SELECT count(*) FROM passes WHERE plate = '${plate}' AND txn_id = '${txnId}' AND status = 'ACTIVE'`,
        ),
      ).toBe(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-021 — B2/B1: application/hal+json → 201 (match is on the suffix, not a fixed list)
  // ---------------------------------------------------------------------------
  test("TC-021 application/hal+json with a valid body returns 201 for a six-month car pass", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `HL${dynamicId}`.slice(0, 10);
    const txnId = `txn_${dynamicId}`;
    try {
      await mock.arm("POST", GATEWAY_PATH, 200, { status: "SUCCESS", txn_id: txnId });
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);

      const res = await api.post("/passes", {
        headers: { "Content-Type": "application/hal+json" },
        data: Buffer.from(JSON.stringify({ vehicle: "car", months: 6, plate }), "utf8"),
      });

      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({
        vehicle: "car",
        months: 6,
        plate,
        currency: "THB",
        txn_id: txnId,
        status: "ACTIVE",
      });

      expect(
        await db.value(
          `SELECT count(*) FROM passes WHERE plate = '${plate}' AND txn_id = '${txnId}' AND status = 'ACTIVE'`,
        ),
      ).toBe(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-022 — B2: text/plain reaches the route unparsed → 400 vehicle is required, no row
  // ---------------------------------------------------------------------------
  test("TC-022 text/plain reaches the route unparsed and returns 400 vehicle is required", async ({
    api,
    db,
    dynamicId,
  }) => {
    const plate = `TP${dynamicId}`.slice(0, 10);
    try {
      const res = await api.post("/passes", {
        headers: { "Content-Type": "text/plain" },
        data: Buffer.from(
          JSON.stringify({ vehicle: "car", months: 2, plate }),
          "utf8",
        ),
      });

      expect(res.status()).toBe(400);
      expect(await res.json()).toMatchObject({ detail: "vehicle is required" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE reference = '${plate}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-023 — B6/X12: vnd.api+json valid body + DECLINED gateway → 402, no passes row
  // ---------------------------------------------------------------------------
  test("TC-023 application/vnd.api+json with a DECLINED gateway returns 402 payment declined and writes no pass", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `DC${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", GATEWAY_PATH, 200, { status: "DECLINED" });

      const res = await api.post("/passes", {
        headers: { "Content-Type": VND_JSON_CT },
        data: Buffer.from(JSON.stringify({ vehicle: "car", months: 3, plate }), "utf8"),
      });

      expect(res.status()).toBe(402);
      expect(await res.json()).toMatchObject({ detail: "payment declined" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE reference = '${plate}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-025 — B7: POST /passes/quote also accepts application/vnd.api+json → 200 with a price
  // ---------------------------------------------------------------------------
  test("TC-025 POST /passes/quote accepts application/vnd.api+json and returns 200 with a price", async ({
    api,
  }) => {
    const res = await api.post("/passes/quote", {
      headers: { "Content-Type": VND_JSON_CT },
      data: Buffer.from(JSON.stringify({ vehicle: "car", months: 3 }), "utf8"),
    });

    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body).toHaveProperty("price");
    expect(typeof body.price).toBe("number");
  });

  // ---------------------------------------------------------------------------
  // TC-026 — B8: vnd.api+json is STATEFUL — one passes row AND one payment_attempts row
  // ---------------------------------------------------------------------------
  test("TC-026 application/vnd.api+json writes exactly one passes row and one payment_attempts row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `ST${dynamicId}`.slice(0, 10);
    const txnId = `txn_${dynamicId}`;
    try {
      await mock.arm("POST", GATEWAY_PATH, 200, { status: "SUCCESS", txn_id: txnId });
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);

      const res = await api.post("/passes", {
        headers: { "Content-Type": VND_JSON_CT },
        data: Buffer.from(JSON.stringify({ vehicle: "car", months: 3, plate }), "utf8"),
      });

      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({ plate, txn_id: txnId, status: "ACTIVE" });

      expect(
        await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}' AND txn_id = '${txnId}'`),
      ).toBe(1);
      expect(await db.value(`SELECT count(*) FROM payment_attempts WHERE txn_id = '${txnId}'`)).toBe(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // TC-027 — B9: two consecutive vnd.api+json requests answer independently (no carried state).
  // Each request carries its OWN body and its OWN gateway txn_id (the txn_id column is UNIQUE
  // since ONODE-23, so a shared id would make the second call a 409 replay, not a fresh parse).
  // ---------------------------------------------------------------------------
  test("TC-027 two consecutive application/vnd.api+json requests each answer independently", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate1 = `S1${dynamicId}`.slice(0, 10);
    const plate2 = `S2${dynamicId}`.slice(0, 10);
    const txnId1 = `txn-a-${dynamicId}`;
    const txnId2 = `txn-b-${dynamicId}`;
    try {
      await db.exec(`DELETE FROM passes WHERE plate IN ('${plate1}', '${plate2}')`);

      await mock.arm("POST", GATEWAY_PATH, 200, { status: "SUCCESS", txn_id: txnId1 });

      const first = await api.post("/passes", {
        headers: { "Content-Type": VND_JSON_CT },
        data: Buffer.from(JSON.stringify({ vehicle: "car", months: 1, plate: plate1 }), "utf8"),
      });
      expect(first.status()).toBe(201);
      expect(await first.json()).toMatchObject({
        vehicle: "car",
        months: 1,
        plate: plate1,
        status: "ACTIVE",
      });

      // Replace the stub with the second, DIFFERENT txn_id: MockServer keeps the first matching
      // expectation, so the previous one must be cleared or the app would still see txn-a.
      await mock.clear();
      await mock.arm("POST", GATEWAY_PATH, 200, { status: "SUCCESS", txn_id: txnId2 });

      const second = await api.post("/passes", {
        headers: { "Content-Type": VND_JSON_CT },
        data: Buffer.from(JSON.stringify({ vehicle: "motorcycle", months: 2, plate: plate2 }), "utf8"),
      });
      expect(second.status()).toBe(201);
      expect(await second.json()).toMatchObject({
        vehicle: "motorcycle",
        months: 2,
        plate: plate2,
        status: "ACTIVE",
      });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate IN ('${plate1}', '${plate2}')`)).toBe(2);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id IN ('${txnId1}', '${txnId2}'); DELETE FROM passes WHERE plate IN ('${plate1}', '${plate2}');`,
      );
    }
  });
});
