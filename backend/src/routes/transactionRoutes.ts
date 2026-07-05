import { asyncHandler } from "../http/asyncHandler";
import { requireAuth, requireUserId } from "../http/authMiddleware";
import { createRouter, type Router } from "../http/express";
import { sendData } from "../http/respond";
import { emptyBodySchema, validate } from "../http/validate";
import type { SiftRepositories } from "../repositories/types";
import type { AuthService } from "../services/authService";
import type { PlaidService } from "../services/plaidService";
import { z } from "../validation/zod";

const transactionsQuerySchema = z.object({
  since: z
    .string()
    .optional()
    .refine((value) => !value || !Number.isNaN(Date.parse(value)), "since must be a date."),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  offset: z.coerce.number().int().min(0).default(0)
});

export function createTransactionRoutes(
  authService: AuthService,
  repositories: SiftRepositories,
  plaidService: PlaidService,
  adminToken?: string
): Router {
  const router = createRouter();

  router.post(
    "/sync",
    requireAuth(authService, adminToken),
    validate({ body: emptyBodySchema }),
    asyncHandler(async (req, res) => {
      sendData(res, await plaidService.syncTransactions(requireUserId(req)));
    })
  );

  router.get(
    "/",
    requireAuth(authService, adminToken),
    validate({ query: transactionsQuerySchema }),
    asyncHandler(async (req, res) => {
      const query = req.query as unknown as {
        since?: string;
        limit: number;
        offset: number;
      };
      const transactions = await repositories.transactions.listByUser({
        userId: requireUserId(req),
        since: query.since ? new Date(query.since) : undefined,
        limit: query.limit,
        offset: query.offset
      });
      sendData(res, transactions);
    })
  );

  return router;
}
