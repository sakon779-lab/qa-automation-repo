import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-46 — POST /passes must answer 4xx (not 500) for requests the framework refuses
 * before the route runs, and must keep every already-delivered answer byte-identical.
 *
 * One test per approved CSV row (test_designs/ONODE-46.csv): TC-001 … TC-023, TC-025.
 *
 * Malformed / exact-byte bodies are sent as Buffer.from(...): Playwright JSON-ENCODES a string
 * under a JSON Content-Type, so `{bad` would leave as the valid JSON `"{bad"` and the server
 * would answer a different error (the ONODE-46 trap named in the role card).
 *
 * FINDING (CSV, TC-020/021/022/023): the rows name the stub path `/external/payment/charge`, but
 * the deployed app calls the gateway at `/charge` — the path the delivered ONODE-16 suite stubs
 * and passes with. Stubbing the CSV's literal path leaves the app's real call unstubbed, so the
 * gateway answers 502 and the row's own expectation (402 for TC-020) is unreachable. The rows are
 * disputed with Athena; the tests below stub the path the app actually calls so the behaviour the
 * row describes is still proven.
 */
const JSON_CT = "application/json";
const GATEWAY_PATH = "/charge";

/** A JSON body of exactly `total` bytes shaped {vehicle, months, plate, pad}. */
function jsonBodyOfSize(total: number, vehicle: string): Buffer {
  const head = `{"vehicle": "${vehicle}", "months": 1, "plate": "AB1", "pad": "`;
  const tail = `"}`;
  const padLen = total - Buffer.byteLength(head) - Buffer.byteLength(tail);
  if (padLen < 0) throw new Error(`jsonBodyOfSize: ${total} bytes is too small for the envelope`);
  return Buffer.from(head + "x".repeat(padLen) + tail, "utf8");
}

test.describe("ONODE-46 — client-side request faults answer 4xx, delivered answers unchanged", () => {
  // ---------------------------------------------------------------------------
  // TC-001 — malformed JSON `{bad` → 400 'request body must be valid JSON'
  // ---------------------------------------------------------------------------
  test("TC-001 malformed JSON body returns 400 request body must be valid JSON", async ({ api }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": JSON_CT },
      data: Buffer.from("{bad", "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "request body must be valid JSON" });
  });

  // ---------------------------------------------------------------------------
  // TC-002 — JSON truncated mid-object → 400 'request body must be valid JSON'
  // ---------------------------------------------------------------------------
  test("TC-002 truncated JSON body returns 400 request body must be valid JSON", async ({ api }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": JSON_CT },
      data: Buffer.from('{"vehicle": "car", "months": 1, "plate": "AB1"', "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "request body must be valid JSON" });
  });

  // ---------------------------------------------------------------------------
  // TC-003 — Content-Type application/xml → 415 'unsupported content type'
  // ---------------------------------------------------------------------------
  test("TC-003 application/xml content type returns 415 unsupported content type", async ({ api }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": "application/xml" },
      data: Buffer.from("<a/>", "utf8"),
    });

    expect(res.status()).toBe(415);
    expect(await res.json()).toMatchObject({ detail: "unsupported content type" });
  });

  // ---------------------------------------------------------------------------
  // TC-004 — Content-Type text/csv → 415 'unsupported content type'
  // ---------------------------------------------------------------------------
  test("TC-004 text/csv content type returns 415 unsupported content type", async ({ api }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": "text/csv" },
      data: Buffer.from("a,b", "utf8"),
    });

    expect(res.status()).toBe(415);
    expect(await res.json()).toMatchObject({ detail: "unsupported content type" });
  });

  // ---------------------------------------------------------------------------
  // TC-005 — JSON body over the 1048576-byte framework default → 413 'request body too large'
  // ---------------------------------------------------------------------------
  test("TC-005 JSON body over 1048576 bytes returns 413 request body too large", async ({ api }) => {
    const body = jsonBodyOfSize(1_153_434, "car");
    expect(body.byteLength).toBe(1_153_434);

    const res = await api.post("/passes", {
      headers: { "Content-Type": JSON_CT },
      data: body,
    });

    expect(res.status()).toBe(413);
    expect(await res.json()).toMatchObject({ detail: "request body too large" });
  });

  // ---------------------------------------------------------------------------
  // TC-006 — text/plain reaches the route → 400 'vehicle is required'
  // ---------------------------------------------------------------------------
  test("TC-006 text/plain body reaches the route and returns 400 vehicle is required", async ({ api }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": "text/plain" },
      data: Buffer.from("hello", "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "vehicle is required" });
  });

  // ---------------------------------------------------------------------------
  // TC-007 — no Content-Type, no body → 400 'vehicle is required'
  // ---------------------------------------------------------------------------
  test("TC-007 no content type and no body returns 400 vehicle is required", async ({ api }) => {
    const res = await api.post("/passes");

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "vehicle is required" });
  });

  // ---------------------------------------------------------------------------
  // TC-008 — JSON body parses to the string "text" → 400 'vehicle is required'
  // ---------------------------------------------------------------------------
  test("TC-008 JSON body parsing to a string returns 400 vehicle is required", async ({ api }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": JSON_CT },
      data: Buffer.from('"text"', "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "vehicle is required" });
  });

  // ---------------------------------------------------------------------------
  // TC-009 — JSON body parses to [] → 400 'vehicle is required'
  // ---------------------------------------------------------------------------
  test("TC-009 JSON body parsing to an array returns 400 vehicle is required", async ({ api }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": JSON_CT },
      data: Buffer.from("[]", "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "vehicle is required" });
  });

  // ---------------------------------------------------------------------------
  // TC-010 — JSON body parses to null → 400 'vehicle is required'
  // ---------------------------------------------------------------------------
  test("TC-010 JSON body parsing to null returns 400 vehicle is required", async ({ api }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": JSON_CT },
      data: Buffer.from("null", "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "vehicle is required" });
  });

  // ---------------------------------------------------------------------------
  // TC-011 — valid JSON, wrong vehicle value → 400 'vehicle must be car or motorcycle'
  // ---------------------------------------------------------------------------
  test("TC-011 wrong vehicle value returns 400 vehicle must be car or motorcycle", async ({ api }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": JSON_CT },
      data: Buffer.from('{"vehicle": "truck", "months": 1, "plate": "AB1"}', "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "vehicle must be car or motorcycle" });
  });

  // ---------------------------------------------------------------------------
  // TC-012 — same malformed JSON on another body-bearing route POST /fees/quote
  // ---------------------------------------------------------------------------
  test("TC-012 malformed JSON on POST /fees/quote returns 400 request body must be valid JSON", async ({ api }) => {
    const res = await api.post("/fees/quote", {
      headers: { "Content-Type": JSON_CT },
      data: Buffer.from("{bad", "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "request body must be valid JSON" });
  });

  // ---------------------------------------------------------------------------
  // TC-013 — empty JSON body → 400 'request body must be valid JSON'
  // ---------------------------------------------------------------------------
  test("TC-013 empty JSON body returns 400 request body must be valid JSON", async ({ api }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": JSON_CT },
      data: Buffer.from("", "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "request body must be valid JSON" });
  });

  // ---------------------------------------------------------------------------
  // TC-014 — vehicle key absent → 400 'vehicle is required'
  // ---------------------------------------------------------------------------
  test("TC-014 missing vehicle key returns 400 vehicle is required", async ({ api }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": JSON_CT },
      data: Buffer.from('{"months": 1, "plate": "AB1"}', "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "vehicle is required" });
  });

  // ---------------------------------------------------------------------------
  // TC-015 — vehicle is a number → 400 'vehicle must be car or motorcycle'
  // ---------------------------------------------------------------------------
  test("TC-015 non-string vehicle value returns 400 vehicle must be car or motorcycle", async ({ api }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": JSON_CT },
      data: Buffer.from('{"vehicle": 42, "months": 1, "plate": "AB1"}', "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "vehicle must be car or motorcycle" });
  });

  // ---------------------------------------------------------------------------
  // TC-016 — months missing → 400 'months is required'
  // ---------------------------------------------------------------------------
  test("TC-016 missing months returns 400 months is required", async ({ api }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": JSON_CT },
      data: Buffer.from('{"vehicle": "car", "plate": "AB1"}', "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "months is required" });
  });

  // ---------------------------------------------------------------------------
  // TC-017 — months out of range (13) → 400 'months must be an integer from 1 to 12'
  // ---------------------------------------------------------------------------
  test("TC-017 out-of-range months returns 400 months must be an integer from 1 to 12", async ({ api }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": JSON_CT },
      data: Buffer.from('{"vehicle": "car", "months": 13, "plate": "AB1"}', "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "months must be an integer from 1 to 12" });
  });

  // ---------------------------------------------------------------------------
  // TC-018 — plate key absent → 400 'plate is required'
  // ---------------------------------------------------------------------------
  test("TC-018 missing plate key returns 400 plate is required", async ({ api }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": JSON_CT },
      data: Buffer.from('{"vehicle": "car", "months": 1}', "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "plate is required" });
  });

  // ---------------------------------------------------------------------------
  // TC-019 — plate longer than 10 chars → 400 'plate must be a string of at most 10 characters'
  // ---------------------------------------------------------------------------
  test("TC-019 over-long plate returns 400 plate must be a string of at most 10 characters", async ({ api }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": JSON_CT },
      data: Buffer.from('{"vehicle": "car", "months": 1, "plate": "ABCDEFGHIJK"}', "utf8"),
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "plate must be a string of at most 10 characters" });
  });

  // ---------------------------------------------------------------------------
  // TC-020 — gateway 200 DECLINED → 402 'payment declined', no pass row written
  // ---------------------------------------------------------------------------
  test("TC-020 declined payment returns 402 payment declined and writes no pass row", async ({
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
        data: Buffer.from(JSON.stringify({ vehicle: "car", months: 1, plate }), "utf8"),
      });

      expect(res.status()).toBe(402);
      expect(await res.json()).toMatchObject({ detail: "payment declined" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-021 — gateway 500 → 502 'payment gateway unavailable', no pass row written
  // ---------------------------------------------------------------------------
  test("TC-021 gateway 500 returns 502 payment gateway unavailable and writes no pass row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", GATEWAY_PATH, 500, { error: "boom" });

      const res = await api.post("/passes", {
        headers: { "Content-Type": JSON_CT },
        data: Buffer.from(JSON.stringify({ vehicle: "car", months: 1, plate }), "utf8"),
      });

      expect(res.status()).toBe(502);
      expect(await res.json()).toMatchObject({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-022 — gateway 200 SUCCESS with empty txn_id → 502, no pass row written
  // ---------------------------------------------------------------------------
  test("TC-022 gateway SUCCESS with empty txn_id returns 502 payment gateway unavailable and writes no pass row", async ({
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
        data: Buffer.from(JSON.stringify({ vehicle: "car", months: 1, plate }), "utf8"),
      });

      expect(res.status()).toBe(502);
      expect(await res.json()).toMatchObject({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-023 — gateway times out (30000ms delay) → 502, no pass row written
  // ---------------------------------------------------------------------------
  test("TC-023 gateway timeout returns 502 payment gateway unavailable and writes no pass row", async ({
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
        data: Buffer.from(JSON.stringify({ vehicle: "car", months: 1, plate }), "utf8"),
      });

      expect(res.status()).toBe(502);
      expect(await res.json()).toMatchObject({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-025 — exactly 1048576 bytes is NOT rejected by the framework; the route
  //          answers its own 400 'vehicle must be car or motorcycle'
  // ---------------------------------------------------------------------------
  test("TC-025 JSON body of exactly 1048576 bytes reaches the route and returns 400 vehicle must be car or motorcycle", async ({
    api,
  }) => {
    const body = jsonBodyOfSize(1_048_576, "truck");
    expect(body.byteLength).toBe(1_048_576);

    const res = await api.post("/passes", {
      headers: { "Content-Type": JSON_CT },
      data: body,
    });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "vehicle must be car or motorcycle" });
  });
});