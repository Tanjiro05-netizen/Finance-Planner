import { createApp } from "./app";
import { loadConfig } from "./config";
import { createLogger } from "./logger";
import { createPrismaReadinessCheck, startupLogContext } from "./ops";
import { createPrismaClient, createPrismaRepositories } from "./repositories/prismaRepositories";

loadDotenvConfig("dotenv/config");

const config = loadConfig();
const logger = createLogger();
const prisma = createPrismaClient();
const app = createApp({
  config,
  logger,
  repositories: createPrismaRepositories(prisma),
  readinessCheck: createPrismaReadinessCheck(prisma)
});

const server = app.listen(config.port, () => {
  logger.info(startupLogContext(config), "Sift backend configured");
  logger.info({ port: config.port }, "Sift backend listening");
});

for (const signal of ["SIGINT", "SIGTERM"] as const) {
  process.on(signal, () => {
    server.close(() => {
      void prisma.$disconnect().finally(() => {
        logger.info({ signal }, "Sift backend stopped");
        process.exit(0);
      });
    });
  });
}

function loadDotenvConfig(moduleName: string): void {
  const runtimeRequire = eval("require") as (name: string) => unknown;
  runtimeRequire(moduleName);
}
