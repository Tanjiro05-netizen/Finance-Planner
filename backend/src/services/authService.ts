import { createHmac, timingSafeEqual } from "node:crypto";
import { unauthorized } from "../errors";
import type { SiftRepositories } from "../repositories/types";

type JwtHeader = {
  alg: "HS256";
  typ: "JWT";
};

type JwtPayload = {
  sub: string;
  iat: number;
  exp: number;
};

export class AuthService {
  constructor(
    private readonly repositories: SiftRepositories,
    private readonly jwtSecret: string,
    private readonly ttlSeconds: number
  ) {}

  async bootstrap(): Promise<{ token: string }> {
    const user = await this.repositories.users.create();
    return { token: this.signToken(user.id) };
  }

  async verifyToken(token: string): Promise<string> {
    const payload = this.verifySignature(token);
    const user = await this.repositories.users.findById(payload.sub);

    if (!user) {
      throw unauthorized("The session is no longer valid.");
    }

    return user.id;
  }

  private signToken(userId: string): string {
    const now = Math.floor(Date.now() / 1000);
    const header: JwtHeader = { alg: "HS256", typ: "JWT" };
    const payload: JwtPayload = {
      sub: userId,
      iat: now,
      exp: now + this.ttlSeconds
    };
    const signingInput = `${base64UrlJson(header)}.${base64UrlJson(payload)}`;
    const signature = hmacSha256(signingInput, this.jwtSecret);
    return `${signingInput}.${signature}`;
  }

  private verifySignature(token: string): JwtPayload {
    const parts = token.split(".");

    if (parts.length !== 3) {
      throw unauthorized("The bearer token is malformed.");
    }

    const [headerPart, payloadPart, signature] = parts;

    if (!headerPart || !payloadPart || !signature) {
      throw unauthorized("The bearer token is malformed.");
    }

    const header = decodeJson<Partial<JwtHeader>>(headerPart);

    if (header.alg !== "HS256" || header.typ !== "JWT") {
      throw unauthorized("The bearer token algorithm is not supported.");
    }

    const expected = hmacSha256(`${headerPart}.${payloadPart}`, this.jwtSecret);

    if (!safeEqual(signature, expected)) {
      throw unauthorized("The bearer token signature is invalid.");
    }

    const payload = decodeJson<Partial<JwtPayload>>(payloadPart);
    const now = Math.floor(Date.now() / 1000);

    if (!payload.sub || typeof payload.sub !== "string") {
      throw unauthorized("The bearer token subject is missing.");
    }

    if (!payload.exp || typeof payload.exp !== "number" || payload.exp <= now) {
      throw unauthorized("The bearer token has expired.");
    }

    return {
      sub: payload.sub,
      iat: typeof payload.iat === "number" ? payload.iat : now,
      exp: payload.exp
    };
  }
}

function hmacSha256(value: string, secret: string): string {
  return createHmac("sha256", secret).update(value).digest("base64url");
}

function base64UrlJson(value: unknown): string {
  return Buffer.from(JSON.stringify(value), "utf8").toString("base64url");
}

function decodeJson<T>(value: string): T {
  try {
    return JSON.parse(Buffer.from(value, "base64url").toString("utf8")) as T;
  } catch {
    throw unauthorized("The bearer token payload is invalid.");
  }
}

function safeEqual(left: string, right: string): boolean {
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);

  if (leftBuffer.length !== rightBuffer.length) {
    return false;
  }

  return timingSafeEqual(leftBuffer, rightBuffer);
}
