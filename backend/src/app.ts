import {
  createExpressApp,
  type ErrorRequestHandler,
  type Express,
  json,
  type RequestHandler
} from "./http/express";
import { randomUUID } from "node:crypto";
import type { AppConfig } from "./config";
import { loadConfig } from "./config";
import { ApiError, badRequest, isApiError } from "./errors";
import { createLogger, type AppLogger } from "./logger";
import {
  createPrismaReadinessCheck,
  createStaticReadinessCheck,
  makeHealthPayload,
  makeReadinessPayload,
  readinessStatusCode,
  type ReadinessChecking
} from "./ops";
import { createAccountRoutes } from "./routes/accountRoutes";
import { createAuthRoutes } from "./routes/authRoutes";
import { createCancellationRoutes } from "./routes/cancellationRoutes";
import { createPlaidRoutes, createPlaidWebhookRoutes } from "./routes/plaidRoutes";
import { createPrivacyRoutes } from "./routes/privacyRoutes";
import { createTransactionRoutes } from "./routes/transactionRoutes";
import { createPrismaClient, createPrismaRepositories } from "./repositories/prismaRepositories";
import type { SiftRepositories } from "./repositories/types";
import { AuthService } from "./services/authService";
import { CancellationService } from "./services/cancellationService";
import { TokenCrypto } from "./services/crypto";
import { createPlaidClient, type PlaidClient } from "./services/plaidClient";
import { PlaidService } from "./services/plaidService";
import { PlaidWebhookVerifier, type WebhookVerifier } from "./services/webhookVerifier";

export type AppDependencies = {
  config?: AppConfig;
  logger?: AppLogger;
  repositories?: SiftRepositories;
  readinessCheck?: ReadinessChecking;
  plaidClient?: PlaidClient;
  webhookVerifier?: WebhookVerifier;
};

export function createApp(dependencies: AppDependencies = {}): Express {
  const config = dependencies.config ?? loadConfig();
  const logger = dependencies.logger ?? createLogger();
  const prisma = dependencies.repositories ? undefined : createPrismaClient();
  const repositories =
    dependencies.repositories ?? createPrismaRepositories(prisma!);
  const readinessCheck =
    dependencies.readinessCheck ??
    (prisma ? createPrismaReadinessCheck(prisma) : createStaticReadinessCheck());
  const plaidClient = dependencies.plaidClient ?? createPlaidClient(config);
  const tokenCrypto = new TokenCrypto(config.tokenEncryptionKey);
  const authService = new AuthService(
    repositories,
    config.jwtSecret,
    config.jwtTtlSeconds
  );
  const webhookVerifier =
    dependencies.webhookVerifier ?? new PlaidWebhookVerifier(plaidClient);
  const plaidService = new PlaidService(
    plaidClient,
    repositories,
    tokenCrypto,
    {
      clientName: config.plaid.clientName,
      webhookUrl: config.plaid.webhookUrl
    },
    webhookVerifier
  );
  const cancellationService = new CancellationService(repositories, {
    conciergeEnabled: config.features.conciergeEnabled
  });
  const app = createExpressApp();

  app.disable("x-powered-by");
  app.use(
    json({
      verify: (req, _res, buffer) => {
        req.rawBody = Buffer.from(buffer);
      }
    })
  );
  app.use(createRequestIdMiddleware());
  app.use(createRequestLogger(logger));

  app.get("/health", (_req, res) => {
    res.json({ data: makeHealthPayload() });
  });
  app.get("/ready", async (_req, res) => {
    const payload = await makeReadinessPayload(readinessCheck);
    res.status(readinessStatusCode(payload)).json({ data: payload });
  });
  app.use("/v1/auth", createAuthRoutes(authService));
  app.use(
    "/v1/plaid",
    createPlaidRoutes(authService, plaidService, config.adminToken)
  );
  app.use(
    "/v1/transactions",
    createTransactionRoutes(authService, repositories, plaidService, config.adminToken)
  );
  app.use("/v1/accounts", createAccountRoutes(authService, repositories, config.adminToken));
  app.use(
    "/v1/webhook",
    createPlaidWebhookRoutes(plaidService)
  );
  app.use(
    "/v1/cancellations",
    createCancellationRoutes(authService, cancellationService, config.adminToken)
  );
  app.use(
    "/v1/privacy",
    createPrivacyRoutes(authService, plaidService, config.adminToken)
  );
  app.use((_req, _res, next) => {
    next(new ApiError(404, "not_found", "Route not found."));
  });
  app.use(createErrorHandler(logger));

  return app;
}

function createRequestIdMiddleware(): RequestHandler {
  return (req, res, next) => {
    const incoming = req.header("x-request-id");
    const requestId = incoming && incoming.length <= 128 ? incoming : randomUUID();
    req.requestId = requestId;
    res.setHeader("X-Request-ID", requestId);
    next();
  };
}

function createRequestLogger(logger: AppLogger): RequestHandler {
  return (req, res, next) => {
    const startedAt = performance.now();
    res.on("finish", () => {
      logger.info(
        {
          requestId: req.requestId,
          method: req.method,
          path: sanitizedPath(req.path),
          statusCode: res.statusCode,
          durationMs: Math.round(performance.now() - startedAt)
        },
        "request completed"
      );
    });
    next();
  };
}

function createErrorHandler(logger: AppLogger): ErrorRequestHandler {
  return (error, req, res, _next) => {
    const apiError = normalizeError(error);

    if (apiError.statusCode >= 500) {
      logger.error(
        {
          requestId: req.requestId,
          code: apiError.code,
          message: apiError.message,
          stack: apiError.stack
        },
        "request failed"
      );
    }

    res.status(apiError.statusCode).json({
      error: {
        code: apiError.code,
        message: apiError.message
      }
    });
  };
}

function sanitizedPath(path: string): string {
  const components = path.split("/").filter(Boolean);
  return `/${components.map((component, index) => {
    const previous = components[index - 1];
    if (previous === "item" || previous === "cancellations") {
      return ":id";
    }
    return component;
  }).join("/")}`;
}

function normalizeError(error: unknown): ApiError {
  if (isApiError(error)) {
    return error;
  }

  if (isZodErrorLike(error)) {
    return badRequest("validation_error", error.message);
  }

  return new ApiError(500, "internal_error", "Something went wrong.");
}

function isZodErrorLike(error: unknown): error is Error {
  return error instanceof Error && error.name === "ZodError";
}
