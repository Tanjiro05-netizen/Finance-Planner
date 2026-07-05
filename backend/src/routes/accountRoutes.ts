import { asyncHandler } from "../http/asyncHandler";
import { requireAuth, requireUserId } from "../http/authMiddleware";
import { createRouter, type Router } from "../http/express";
import { sendData } from "../http/respond";
import type { SiftRepositories } from "../repositories/types";
import type { AuthService } from "../services/authService";

export function createAccountRoutes(
  authService: AuthService,
  repositories: SiftRepositories,
  adminToken?: string
): Router {
  const router = createRouter();

  router.get(
    "/",
    requireAuth(authService, adminToken),
    asyncHandler(async (req, res) => {
      const userId = requireUserId(req);
      const accounts = await repositories.accounts.listByUser(userId);
      const items = await repositories.plaidItems.listByUser(userId);
      const itemsById = new Map(items.map((item) => [item.id, item]));
      sendData(
        res,
        accounts.map((account) => {
          const item = itemsById.get(account.plaidItemId);

          return {
            id: account.id,
            plaidItemId: account.plaidItemId,
            institutionName: item?.institutionName ?? "Linked institution",
            mask: account.mask,
            name: account.name,
            type: account.type,
            status: item?.status ?? "error"
          };
        })
      );
    })
  );

  return router;
}
