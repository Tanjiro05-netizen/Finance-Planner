import { asyncHandler } from "../http/asyncHandler";
import { requireAuth, requireUserId } from "../http/authMiddleware";
import { createRouter, type Router } from "../http/express";
import { sendData } from "../http/respond";
import type { AuthService } from "../services/authService";
import type { PlaidService } from "../services/plaidService";

export function createPrivacyRoutes(
  authService: AuthService,
  plaidService: PlaidService,
  adminToken?: string
): Router {
  const router = createRouter();

  router.delete(
    "/data",
    requireAuth(authService, adminToken),
    asyncHandler(async (req, res) => {
      sendData(res, await plaidService.deleteUserData(requireUserId(req)));
    })
  );

  return router;
}
