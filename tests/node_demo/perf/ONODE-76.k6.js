import http from 'k6/http';
import { check, fail } from 'k6';

/**
 * ONODE-76 — measure POST /passes/quote and GET /passes/{id} on the perf stack.
 *
 * Measure-only card: no app code, no schema change. The two budgets are the card's own numbers,
 * copied verbatim into `options.thresholds` — never loosened to make a run pass. A budget the
 * system cannot meet is a finding, not a threshold to edit.
 *
 *   POST /passes/quote  10 VUs / 30s  p(95) < 300 ms  error rate < 1%   (pure pricing, no DB)
 *   GET  /passes/{id}   10 VUs / 30s  p(95) < 500 ms  error rate < 1%   (each VU reads its own pass)
 *
 * The GET scenario needs a pass per VU. Those are created in setup() through POST /passes with the
 * payment gateway stubbed on the perf stack's MockServer (__ENV.MOCK_URL). Requests made in setup()
 * carry no `name` tag, so they count for no budget — exactly as the card says.
 *
 * Target comes from __ENV.BASE_URL (the perf stack only — never the QA stack the functional suite
 * uses).
 *
 * Re-run safety: this script runs nightly against the SAME database, so every plate and txn_id is
 * built from a run stamp made in setup() — a value fixed per VU would be taken on the second run.
 * There is no DELETE endpoint, so nothing is torn down; the unique stamp is what keeps runs apart.
 */

const BASE_URL = __ENV.BASE_URL;
const MOCK_URL = __ENV.MOCK_URL;

// One pass per VU for the GET scenario (10 VUs).
const GET_VUS = 10;

/** Unique plate per run/VU — <= 10 chars, the app's own limit. */
function plateFor(run, vu) {
  return `P${run}${vu}`.slice(0, 10);
}

/**
 * Arm the perf stack's MockServer so POST /passes can charge the gateway.
 * The stub is global (no X-Request-Id scope here: k6 is not the Playwright fixture), so it is
 * created once in setup() and cleared in teardown().
 */
function armGateway(txnId) {
  if (!MOCK_URL) return;
  const res = http.put(
    `${MOCK_URL}/mockserver/expectation`,
    JSON.stringify({
      httpRequest: { method: 'POST', path: '/charge' },
      httpResponse: {
        statusCode: 200,
        headers: { 'Content-Type': ['application/json'] },
        body: JSON.stringify({ status: 'SUCCESS', txn_id: txnId }),
      },
    }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  check(res, { 'gateway stub armed': (r) => r.status === 201 });
}

function clearGateway() {
  if (!MOCK_URL) return;
  http.put(
    `${MOCK_URL}/mockserver/clear`,
    JSON.stringify({ path: '/charge' }),
    { headers: { 'Content-Type': 'application/json' } },
  );
}

export const options = {
  scenarios: {
    post_passes_quote: {
      executor: 'constant-vus',
      vus: 10,
      duration: '30s',
      exec: 'quoteScenario',
    },
    get_passes_id: {
      executor: 'constant-vus',
      vus: GET_VUS,
      duration: '30s',
      exec: 'getPassScenario',
      startTime: '31s',
    },
  },
  thresholds: {
    'http_req_duration{name:post_passes_quote}': ['p(95)<300'],
    'http_req_failed{name:post_passes_quote}': ['rate<0.01'],
    'http_req_duration{name:get_passes_id}': ['p(95)<500'],
    'http_req_failed{name:get_passes_id}': ['rate<0.01'],
  },
};

/**
 * setup() — create one ACTIVE pass per GET VU. These requests carry NO `name` tag, so they count
 * for no budget. Returns the ids the GET scenario reads.
 */
export function setup() {
  // Unique per RUN: the script is re-run nightly against the same database.
  const run = Date.now().toString(36);
  const passIds = [];

  for (let vu = 1; vu <= GET_VUS; vu++) {
    const txnId = `txn_perf_${run}_${vu}`;
    armGateway(txnId);

    const res = http.post(
      `${BASE_URL}/passes`,
      JSON.stringify({ vehicle: 'car', months: 1, plate: plateFor(run, vu) }),
      { headers: { 'Content-Type': 'application/json' } },
    );
    check(res, { 'setup: pass created': (r) => r.status === 201 });
    if (res.status === 201) {
      passIds.push(res.json('id'));
    }
  }

  return { passIds, run };
}

/** POST /passes/quote — pure pricing, no database. Tagged for its budget. */
export function quoteScenario() {
  const res = http.post(
    `${BASE_URL}/passes/quote`,
    JSON.stringify({ vehicle: 'car', months: 3 }),
    {
      headers: { 'Content-Type': 'application/json' },
      tags: { name: 'post_passes_quote' },
    },
  );
  check(res, { 'quote answers 200': (r) => r.status === 200 });
}

/** GET /passes/{id} — each VU reads its own pass. Tagged for its budget. */
export function getPassScenario(data) {
  const ids = (data && data.passIds) || [];
  // A scenario with nothing to measure must fail, never return quietly: a budget that saw 0
  // requests is NOT held.
  if (ids.length === 0) {
    fail('get_passes_id: setup() created no pass — nothing to measure, budget not held');
  }

  const id = ids[(__VU - 1) % ids.length];
  const res = http.get(`${BASE_URL}/passes/${id}`, {
    tags: { name: 'get_passes_id' },
  });
  check(res, { 'get pass answers 200': (r) => r.status === 200 });
}

/** teardown() — drop the gateway stub. There is no DELETE endpoint, so seeded passes stay. */
export function teardown() {
  clearGateway();
}
