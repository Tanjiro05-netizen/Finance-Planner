type Environment = Record<string, string | undefined>;

export type AppConfig = {
  nodeEnv: string;
  port: number;
  databaseUrl: string;
  jwtSecret: string;
  jwtTtlSeconds: number;
  tokenEncryptionKey: string;
  adminToken?: string;
  features: {
    conciergeEnabled: boolean;
  };
  plaid: {
    env: "sandbox" | "development" | "production";
    clientId: string;
    secret: string;
    clientName: string;
    webhookUrl?: string;
  };
};

export function loadConfig(env: Environment = readRuntimeEnv()): AppConfig {
  const data = {
    NODE_ENV: env.NODE_ENV ?? "development",
    PORT: readPositiveInt(env.PORT, 3000, "PORT"),
    DATABASE_URL: readRequired(env.DATABASE_URL, "DATABASE_URL"),
    JWT_SECRET: readMinLength(env.JWT_SECRET, 32, "JWT_SECRET"),
    JWT_TTL_SECONDS: readPositiveInt(env.JWT_TTL_SECONDS, 2_592_000, "JWT_TTL_SECONDS"),
    TOKEN_ENCRYPTION_KEY: readRequired(env.TOKEN_ENCRYPTION_KEY, "TOKEN_ENCRYPTION_KEY"),
    PLAID_ENV: readPlaidEnv(env.PLAID_ENV),
    PLAID_CLIENT_ID: readRequired(env.PLAID_CLIENT_ID, "PLAID_CLIENT_ID"),
    PLAID_SECRET: readRequired(env.PLAID_SECRET, "PLAID_SECRET"),
    PLAID_CLIENT_NAME: readMaxLength(env.PLAID_CLIENT_NAME ?? "Sift", 30, "PLAID_CLIENT_NAME"),
    PLAID_WEBHOOK_URL: readOptionalUrl(env.PLAID_WEBHOOK_URL, "PLAID_WEBHOOK_URL"),
    CONCIERGE_ENABLED: readBoolean(env.CONCIERGE_ENABLED, false, "CONCIERGE_ENABLED"),
    ADMIN_TOKEN: env.ADMIN_TOKEN
      ? readMinLength(env.ADMIN_TOKEN, 16, "ADMIN_TOKEN")
      : undefined
  };

  return {
    nodeEnv: data.NODE_ENV,
    port: data.PORT,
    databaseUrl: data.DATABASE_URL,
    jwtSecret: data.JWT_SECRET,
    jwtTtlSeconds: data.JWT_TTL_SECONDS,
    tokenEncryptionKey: data.TOKEN_ENCRYPTION_KEY,
    adminToken: data.ADMIN_TOKEN,
    features: {
      conciergeEnabled: data.CONCIERGE_ENABLED
    },
    plaid: {
      env: data.PLAID_ENV,
      clientId: data.PLAID_CLIENT_ID,
      secret: data.PLAID_SECRET,
      clientName: data.PLAID_CLIENT_NAME,
      webhookUrl: data.PLAID_WEBHOOK_URL
    }
  };
}

function readBoolean(value: string | undefined, fallback: boolean, name: string): boolean {
  if (value === undefined) {
    return fallback;
  }

  const normalized = value.toLowerCase();
  if (["1", "true", "yes"].includes(normalized)) {
    return true;
  }

  if (["0", "false", "no"].includes(normalized)) {
    return false;
  }

  throw new Error(`Invalid backend configuration: ${name} must be true or false.`);
}

function readRuntimeEnv(): Environment {
  return (globalThis as unknown as { process: { env: Environment } }).process.env;
}

function readRequired(value: string | undefined, name: string): string {
  if (!value) {
    throw new Error(`Invalid backend configuration: ${name} is required.`);
  }

  return value;
}

function readMinLength(value: string | undefined, minLength: number, name: string): string {
  const present = readRequired(value, name);

  if (present.length < minLength) {
    throw new Error(
      `Invalid backend configuration: ${name} must be at least ${minLength} characters.`
    );
  }

  return present;
}

function readMaxLength(value: string, maxLength: number, name: string): string {
  if (value.length > maxLength) {
    throw new Error(
      `Invalid backend configuration: ${name} must be at most ${maxLength} characters.`
    );
  }

  return value;
}

function readPositiveInt(value: string | undefined, fallback: number, name: string): number {
  const parsed = value === undefined ? fallback : Number(value);

  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(`Invalid backend configuration: ${name} must be a positive integer.`);
  }

  return parsed;
}

function readPlaidEnv(value: string | undefined): "sandbox" | "development" | "production" {
  const plaidEnv = value ?? "sandbox";

  if (plaidEnv !== "sandbox" && plaidEnv !== "development" && plaidEnv !== "production") {
    throw new Error(
      "Invalid backend configuration: PLAID_ENV must be sandbox, development, or production."
    );
  }

  return plaidEnv;
}

function readOptionalUrl(value: string | undefined, name: string): string | undefined {
  if (!value) {
    return undefined;
  }

  try {
    new URL(value);
    return value;
  } catch {
    throw new Error(`Invalid backend configuration: ${name} must be a URL.`);
  }
}
