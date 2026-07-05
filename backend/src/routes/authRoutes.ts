import { asyncHandler } from "../http/asyncHandler";
import { createRouter, type Router } from "../http/express";
import { sendData } from "../http/respond";
import { emptyBodySchema, validate } from "../http/validate";
import type { AuthService } from "../services/authService";

export function createAuthRoutes(authService: AuthService): Router {
  const router = createRouter();

  router.post(
    "/bootstrap",
    validate({ body: emptyBodySchema }),
    asyncHandler(async (_req, res) => {
      sendData(res, await authService.bootstrap(), 201);
    })
  );

  return router;
}
