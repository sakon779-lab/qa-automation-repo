import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-78 — GET /passes/{id} with an over-long id must answer the declared 404
 * `pass not found`, not the framework's 414 FST_ERR_MAX_PARAM_LENGTH body.
 *
 * Both rows are stateless negative API cases: no seed, no stub, no teardown.
 */
test.describe("ONODE-78 — over-long pass id answers the declared 404", () => {
  test("TC-001 GET /passes/{id} with a 200-char digit id answers 404 pass not found", async ({ api }) => {
    // Steps: GET /passes/<200 '1' characters> (the replay's {{repeat:1:200}})
    const id = "1".repeat(200);
    expect(id).toHaveLength(200);

    const res = await api.get(`/passes/${id}`);

    // ExpectedResult: HTTP 404 Not Found. JSON contains {'detail': 'pass not found'}
    expect(res.status()).toBe(404);
    const body = await res.json();
    expect(body).toMatchObject({ detail: "pass not found" });
  });

  test("TC-002 GET /passes/{id} with a 5000-char digit id answers 404 with no framework keys and no echoed path", async ({ api }) => {
    // Steps: GET /passes/<5000 '1' characters> (the replay's {{repeat:1:5000}})
    const id = "1".repeat(5000);
    expect(id).toHaveLength(5000);

    const res = await api.get(`/passes/${id}`);

    // ExpectedResult: HTTP 404 Not Found. JSON contains {'detail': 'pass not found'}
    expect(res.status()).toBe(404);
    const body = (await res.json()) as Record<string, unknown>;
    expect(body).toMatchObject({ detail: "pass not found" });

    // No framework keys (the 414 FST_ERR_MAX_PARAM_LENGTH body carries code/error/statusCode)
    expect(body).not.toHaveProperty("code");
    expect(body).not.toHaveProperty("error");
    expect(body).not.toHaveProperty("statusCode");
    expect(JSON.stringify(body)).not.toContain("FST_ERR_MAX_PARAM_LENGTH");

    // No echoed path: the over-long id must not come back in the body
    expect(JSON.stringify(body)).not.toContain(id);
  });
});
