export type AppLogger = {
  info(payload: Record<string, unknown>, message: string): void;
  error(payload: Record<string, unknown>, message: string): void;
};

type PinoFactory = (options: Record<string, unknown>) => AppLogger;

export function createLogger(level = process.env.LOG_LEVEL ?? "info"): AppLogger {
  return loadPino("pino")(createLoggerOptions(level));
}

export function createLoggerOptions(level = process.env.LOG_LEVEL ?? "info"): Record<string, unknown> {
  return {
    base: undefined,
    level,
    redact: [
      "authorization",
      "headers.authorization",
      "*.access_token",
      "*.public_token",
      "*.link_token",
      "*.secret",
      "*.client_secret",
      "*.accessTokenEnc"
    ]
  };
}

export function createSilentLogger(): AppLogger {
  return loadPino("pino")({ enabled: false });
}

function loadPino(moduleName: string): PinoFactory {
  const runtimeRequire = eval("require") as (name: string) => unknown;
  return runtimeRequire(moduleName) as PinoFactory;
}
