import type { AppConfig } from "./config";
import type { PrismaRuntimeClient } from "./repositories/prismaRepositories";

const serviceName = "sift-backend";

export type HealthPayload = {
  ok: true;
  service: string;
  version: string;
  build: string;
  timestamp: string;
};

export type ReadinessPayload = {
  ok: boolean;
  database: "reachable" | "unreachable";
  timestamp: string;
};

export type ReadinessChecking = {
  check(): Promise<ReadinessPayload["database"]>;
};

export function makeHealthPayload(now: Date = new Date()): HealthPayload {
  return {
    ok: true,
    service: serviceName,
    version: packageVersion(),
    build: buildIdentifier(),
    timestamp: now.toISOString()
  };
}

export async function makeReadinessPayload(
  readinessCheck: ReadinessChecking,
  now: Date = new Date()
): Promise<ReadinessPayload> {
  const database = await readinessCheck.check();

  return {
    ok: database === "reachable",
    database,
    timestamp: now.toISOString()
  };
}

export function readinessStatusCode(payload: ReadinessPayload): 200 | 503 {
  return payload.ok ? 200 : 503;
}

export function createPrismaReadinessCheck(
  prisma: PrismaRuntimeClient
): ReadinessChecking {
  return {
    async check() {
      try {
        await prisma.$queryRaw`SELECT 1`;
        return "reachable";
      } catch {
        return "unreachable";
      }
    }
  };
}

export function createStaticReadinessCheck(
  database: ReadinessPayload["database"] = "reachable"
): ReadinessChecking {
  return {
    async check() {
      return database;
    }
  };
}

export function startupLogContext(config: AppConfig): Record<string, unknown> {
  return {
    service: serviceName,
    version: packageVersion(),
    build: buildIdentifier(),
    port: config.port,
    nodeEnv: config.nodeEnv,
    plaidEnv: config.plaid.env,
    plaidWebhookConfigured: Boolean(config.plaid.webhookUrl),
    conciergeEnabled: config.features.conciergeEnabled
  };
}

function buildIdentifier(): string {
  return process.env.SIFT_BUILD ?? "local";
}

function packageVersion(): string {
  const packageJson = loadPackageJson("../package.json");
  return typeof packageJson.version === "string" ? packageJson.version : "0.0.0";
}

function loadPackageJson(path: string): { version?: unknown } {
  const runtimeRequire = eval("require") as (name: string) => unknown;
  return runtimeRequire(path) as { version?: unknown };
}
