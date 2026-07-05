import { describe, expect, test } from "vitest";
import { createLoggerOptions } from "../src/logger";
import {
  makeHealthPayload,
  makeReadinessPayload,
  readinessStatusCode,
  startupLogContext
} from "../src/ops";
import { testConfig } from "./helpers";

describe("ops endpoints", () => {
  test("health payload returns public service metadata", () => {
    const body = { data: makeHealthPayload(new Date("2026-07-03T12:00:00.000Z")) };

    expect(body).toMatchObject({
      data: {
        ok: true,
        service: "sift-backend",
        version: expect.any(String),
        build: expect.any(String),
        timestamp: expect.any(String)
      }
    });
    expect(JSON.stringify(body)).not.toContain(testConfig.plaid.secret);
  });

  test("readiness payload reports database reachability and uses 503 on failure", async () => {
    const healthy = await makeReadinessPayload({
      async check() {
        return "reachable";
      }
    });
    expect({ data: healthy }).toMatchObject({
      data: {
        ok: true,
        database: "reachable",
        timestamp: expect.any(String)
      }
    });
    expect(readinessStatusCode(healthy)).toBe(200);

    const unhealthy = await makeReadinessPayload({
      async check() {
        return "unreachable";
      }
    });
    expect({ data: unhealthy }).toMatchObject({
      data: {
        ok: false,
        database: "unreachable",
        timestamp: expect.any(String)
      }
    });
    expect(readinessStatusCode(unhealthy)).toBe(503);
  });

  test("startup logging and logger options omit secrets", () => {
    const context = startupLogContext(testConfig);
    const serialized = JSON.stringify(context);

    expect(context).toMatchObject({
      plaidEnv: "sandbox",
      plaidWebhookConfigured: true,
      conciergeEnabled: true
    });
    expect(serialized).not.toContain(testConfig.plaid.secret);
    expect(serialized).not.toContain(testConfig.jwtSecret);
    expect(serialized).not.toContain(testConfig.tokenEncryptionKey);

    const loggerOptions = createLoggerOptions("debug");
    expect(loggerOptions).toMatchObject({ level: "debug" });
    expect(loggerOptions.redact).toEqual(
      expect.arrayContaining([
        "*.access_token",
        "*.public_token",
        "*.link_token",
        "*.secret",
        "*.client_secret",
        "*.accessTokenEnc"
      ])
    );
  });

  test("health payload is deterministic when a timestamp is supplied", () => {
    expect(makeHealthPayload(new Date("2026-07-03T12:00:00.000Z"))).toMatchObject({
      ok: true,
      service: "sift-backend",
      timestamp: "2026-07-03T12:00:00.000Z"
    });
  });
});
