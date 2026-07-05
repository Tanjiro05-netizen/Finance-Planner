import { timingSafeEqual } from "node:crypto";
import { unauthorized } from "../errors";
import type { AuthService } from "../services/authService";
import type { NextFunction, Request, RequestHandler, Response } from "./express";

export function requireAuth(authService: AuthService, adminToken?: string): RequestHandler {
  return (req: Request, _res: Response, next: NextFunction) => {
    void authenticate(req, authService, adminToken).then(() => next(), next);
  };
}

export function requireUserId(req: Request): string {
  if (!req.userId) {
    throw unauthorized();
  }

  return req.userId;
}

async function authenticate(
  req: Request,
  authService: AuthService,
  adminToken?: string
): Promise<void> {
  const header = req.header("authorization");

  if (!header?.startsWith("Bearer ")) {
    throw unauthorized();
  }

  const token = header.slice("Bearer ".length).trim();
  req.userId = await authService.verifyToken(token);
  req.isAdmin = isAdminRequest(req.header("x-admin-token"), adminToken);
}

function isAdminRequest(value: string | undefined, expected: string | undefined): boolean {
  if (!value || !expected) {
    return false;
  }

  const left = Buffer.from(value);
  const right = Buffer.from(expected);

  if (left.length !== right.length) {
    return false;
  }

  return timingSafeEqual(left, right);
}
