import { asyncHandler } from "../http/asyncHandler";
import { requireAuth, requireUserId } from "../http/authMiddleware";
import { createRouter, type Router } from "../http/express";
import { sendData } from "../http/respond";
import { validate } from "../http/validate";
import type { AuthService } from "../services/authService";
import type { CancellationService } from "../services/cancellationService";
import { z } from "../validation/zod";

const createCancellationSchema = z.object({
  subscriptionRef: z.string().min(1).max(128),
  merchantName: z.string().min(1).max(160),
  method: z.enum(["concierge", "guided"])
});

const cancellationParamsSchema = z.object({
  id: z.string().min(1)
});

const advanceCancellationSchema = z.object({
  status: z.enum(["contacting", "confirmed", "needsUser", "cancelledByUser"]),
  note: z.string().max(2_000).optional()
});

export function createCancellationRoutes(
  authService: AuthService,
  cancellationService: CancellationService,
  adminToken?: string
): Router {
  const router = createRouter();

  router.post(
    "/",
    requireAuth(authService, adminToken),
    validate({ body: createCancellationSchema }),
    asyncHandler(async (req, res) => {
      sendData(
        res,
        await cancellationService.create({
          userId: requireUserId(req),
          subscriptionRef: req.body.subscriptionRef,
          merchantName: req.body.merchantName,
          method: req.body.method
        }),
        201
      );
    })
  );

  router.get(
    "/",
    requireAuth(authService, adminToken),
    asyncHandler(async (req, res) => {
      sendData(res, await cancellationService.list(requireUserId(req)));
    })
  );

  router.patch(
    "/:id",
    requireAuth(authService, adminToken),
    validate({ params: cancellationParamsSchema, body: advanceCancellationSchema }),
    asyncHandler(async (req, res) => {
      sendData(
        res,
        await cancellationService.advance({
          userId: requireUserId(req),
          id: req.params.id as string,
          status: req.body.status,
          note: req.body.note
        })
      );
    })
  );

  return router;
}
