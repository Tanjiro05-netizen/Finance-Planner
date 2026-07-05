import { badRequest } from "../errors";
import { asyncHandler } from "../http/asyncHandler";
import { requireAuth, requireUserId } from "../http/authMiddleware";
import { createRouter, type Router } from "../http/express";
import { sendData } from "../http/respond";
import { emptyBodySchema, validate } from "../http/validate";
import type { AuthService } from "../services/authService";
import type { PlaidService } from "../services/plaidService";
import { z } from "../validation/zod";

const exchangeBodySchema = z.object({
  public_token: z.string().min(1)
});

const plaidItemParamsSchema = z.object({
  id: z.string().min(1)
});

const webhookBodySchema = z
  .object({
    item_id: z.string().optional()
  })
  .passthrough();

export function createPlaidRoutes(
  authService: AuthService,
  plaidService: PlaidService,
  adminToken?: string
): Router {
  const router = createRouter();

  router.post(
    "/link-token",
    requireAuth(authService, adminToken),
    validate({ body: emptyBodySchema }),
    asyncHandler(async (req, res) => {
      sendData(res, await plaidService.createLinkToken(requireUserId(req)));
    })
  );

  router.post(
    "/exchange",
    requireAuth(authService, adminToken),
    validate({ body: exchangeBodySchema }),
    asyncHandler(async (req, res) => {
      sendData(res, await plaidService.exchangePublicToken(requireUserId(req), req.body.public_token));
    })
  );

  router.delete(
    "/item/:id",
    requireAuth(authService, adminToken),
    validate({ params: plaidItemParamsSchema }),
    asyncHandler(async (req, res) => {
      sendData(res, await plaidService.removeLinkedItem(requireUserId(req), req.params.id as string));
    })
  );

  return router;
}

export function createPlaidWebhookRoutes(plaidService: PlaidService): Router {
  const router = createRouter();

  router.post(
    "/plaid",
    validate({ body: webhookBodySchema }),
    asyncHandler(async (req, res) => {
      const signature = req.header("Plaid-Verification");

      if (!signature) {
        throw badRequest("invalid_webhook_signature", "Plaid webhook signature is missing.");
      }

      const isValid = await plaidService.verifyWebhook(
        signature,
        req.rawBody ?? Buffer.from(JSON.stringify(req.body), "utf8")
      );

      if (!isValid) {
        throw badRequest("invalid_webhook_signature", "Plaid webhook signature is invalid.");
      }

      sendData(res, await plaidService.markItemNeedsSync(req.body.item_id));
    })
  );

  return router;
}
