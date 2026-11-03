/**
 * Shared, project-AGNOSTIC Playwright fixtures — the TypeScript twin of
 * resources/common/keywords.robot. Every project's spec imports its `test` from here:
 *
 *   import { test, expect } from "../../resources/playwright/fixtures";
 *
 *   test("TC-002 buys a pass", async ({ api, db, mock, dynamicId }) => { ... });
 *
 * What each test gets (all lazy — a stateless test opens no DB connection):
 *   requestId  a fresh UUID; `api` sends it as X-Request-Id and `mock` scopes every stub to it
 *   api        an HTTP client on the project's baseURL that carries this test's X-Request-Id
 *              (the app forwards it to the external service, so stubs never cross tests)
 *   dynamicId  a unique integer for <dynamic_id> — safe under the fully-parallel run
 *   db         exec(sql) · rows(sql) · value(sql) on the project's QA database
 *   mock       arm(method, path, status, body) · received(method, path) · clear()
 *              — stubs armed here are cleared when the test ends (never /mockserver/reset:
 *              a global wipe deletes what a parallel test just armed)
 *
 * Addresses come from the project's playwright.config.ts: `use: { baseURL, dbUrl, mockUrl }`,
 * each env-overridable there — the same role config.robot plays for a Robot project.
 */
import { randomUUID } from "node:crypto";
import { test as base, expect, type APIRequestContext } from "@playwright/test";
import pg from "pg";

export interface Db {
  /** Run one or more `;`-separated statements (seed / teardown). */
  exec(sql: string): Promise<void>;
  /** Every row of a query. */
  rows<T = Record<string, unknown>>(sql: string): Promise<T[]>;
  /** The first column of the first row (undefined when no row) — `SELECT count(*) …` → number. */
  value<T = unknown>(sql: string): Promise<T>;
}

export interface Mock {
  /** Stub `method path` to answer `status` + JSON `body` — only for requests carrying this test's X-Request-Id. */
  arm(method: string, path: string, status: number, body?: unknown, opts?: { delayMs?: number }): Promise<void>;
  /** The requests the APP actually sent to `method path` under this test's X-Request-Id. */
  received(method: string, path: string): Promise<Array<Record<string, unknown>>>;
  /** Remove this test's stubs (runs automatically when the test ends). */
  clear(): Promise<void>;
}

interface Options {
  dbUrl: string;
  mockUrl: string;
}

interface Fixtures {
  requestId: string;
  dynamicId: number;
  api: APIRequestContext;
  db: Db;
  mock: Mock;
}

let lastId = 0;
/** Unique per worker process and monotonic within it; the pid keeps parallel workers apart. */
function nextId(): number {
  const base = (Date.now() % 100_000) * 1_000 + (process.pid % 1_000);
  lastId = Math.max(lastId + 1, base);
  return lastId % 2_000_000_000;
}

// count(*) and other bigint columns come back as strings by default; a test compares numbers
pg.types.setTypeParser(20, (v: string) => {
  const n = Number(v);
  return Number.isSafeInteger(n) ? n : v;
});

export const test = base.extend<Fixtures & Options>({
  dbUrl: ["", { option: true }],
  mockUrl: ["", { option: true }],

  requestId: async ({}, use) => {
    await use(randomUUID());
  },

  dynamicId: async ({}, use) => {
    await use(nextId());
  },

  api: async ({ playwright, baseURL, requestId }, use) => {
    const ctx = await playwright.request.newContext({
      baseURL,
      extraHTTPHeaders: { "X-Request-Id": requestId },
    });
    await use(ctx);
    await ctx.dispose();
  },

  db: async ({ dbUrl }, use) => {
    if (!dbUrl) {
      throw new Error("db fixture: this project declares no database — set `use: { dbUrl }` in its playwright.config.ts");
    }
    const client = new pg.Client({ connectionString: dbUrl });
    await client.connect();
    try {
      await use({
        exec: async (sql) => {
          await client.query(sql);
        },
        rows: async (sql) => (await client.query(sql)).rows,
        value: async (sql) => {
          const first = (await client.query(sql)).rows[0];
          return (first ? Object.values(first)[0] : undefined) as never;
        },
      });
    } finally {
      await client.end();
    }
  },

  mock: async ({ playwright, mockUrl, requestId }, use) => {
    if (!mockUrl) {
      throw new Error("mock fixture: this project declares no mock server — set `use: { mockUrl }` in its playwright.config.ts");
    }
    const ms = await playwright.request.newContext({ baseURL: mockUrl });
    // MockServer matches headers as name -> LIST of values; a bare string silently matches nothing
    const scope = { "X-Request-Id": [requestId] };
    const mock: Mock = {
      arm: async (method, path, status, body, opts) => {
        const res = await ms.put("/mockserver/expectation", {
          data: {
            httpRequest: { method: method.toUpperCase(), path, headers: scope },
            httpResponse: {
              statusCode: status,
              headers: { "Content-Type": ["application/json"] },
              ...(body === undefined ? {} : { body: JSON.stringify(body) }),
              ...(opts?.delayMs ? { delay: { timeUnit: "MILLISECONDS", value: opts.delayMs } } : {}),
            },
          },
        });
        expect(res.status(), `MockServer refused the expectation for ${method} ${path}`).toBe(201);
      },
      received: async (method, path) => {
        const res = await ms.put("/mockserver/retrieve?type=REQUESTS&format=JSON", {
          data: { method: method.toUpperCase(), path, headers: scope },
        });
        expect(res.status()).toBe(200);
        return res.json();
      },
      clear: async () => {
        await ms.put("/mockserver/clear", { data: { headers: scope } }).catch(() => undefined);
      },
    };
    try {
      await use(mock);
    } finally {
      await mock.clear();
      await ms.dispose();
    }
  },
});

export { expect };
