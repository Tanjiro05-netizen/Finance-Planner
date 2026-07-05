import { createHash, createPublicKey, verify } from "node:crypto";
import type { JWKPublicKey, PlaidClient } from "./plaidClient";

type WebhookJwtHeader = {
  alg?: string;
  kid?: string;
  typ?: string;
};

type WebhookJwtPayload = {
  iat?: number;
  exp?: number;
  request_body_sha256?: string;
};

export type WebhookVerifier = {
  verify(signature: string, rawBody: Buffer): Promise<boolean>;
};

export class PlaidWebhookVerifier implements WebhookVerifier {
  constructor(private readonly plaidClient: PlaidClient) {}

  async verify(signature: string, rawBody: Buffer): Promise<boolean> {
    const parts = signature.split(".");

    if (parts.length !== 3) {
      return false;
    }

    const [headerPart, payloadPart, signaturePart] = parts;

    if (!headerPart || !payloadPart || !signaturePart) {
      return false;
    }

    const header = decodePart<WebhookJwtHeader>(headerPart);
    const payload = decodePart<WebhookJwtPayload>(payloadPart);

    if (!header || !payload || header.alg !== "ES256" || !header.kid) {
      return false;
    }

    if (!payload.request_body_sha256 || !matchesBodyHash(payload.request_body_sha256, rawBody)) {
      return false;
    }

    const now = Math.floor(Date.now() / 1000);

    if (typeof payload.exp === "number" && payload.exp <= now) {
      return false;
    }

    const response = await this.plaidClient.webhookVerificationKeyGet({
      key_id: header.kid
    });
    const key = response.data.key;

    if (!isUsableKey(key, now)) {
      return false;
    }

    const publicKey = createPublicKey({
      format: "jwk",
      key: {
        alg: key.alg,
        crv: key.crv,
        ext: true,
        kid: key.kid,
        kty: key.kty,
        use: key.use,
        x: key.x,
        y: key.y
      }
    });

    return verify(
      "sha256",
      Buffer.from(`${headerPart}.${payloadPart}`),
      { key: publicKey, dsaEncoding: "ieee-p1363" },
      Buffer.from(signaturePart, "base64url")
    );
  }
}

function decodePart<T>(part: string): T | null {
  try {
    return JSON.parse(Buffer.from(part, "base64url").toString("utf8")) as T;
  } catch {
    return null;
  }
}

function matchesBodyHash(expected: string, rawBody: Buffer): boolean {
  const actual = createHash("sha256").update(rawBody).digest("hex");
  return expected === actual;
}

function isUsableKey(key: JWKPublicKey, now: number): boolean {
  if (key.alg !== "ES256" || key.kty !== "EC" || key.crv !== "P-256") {
    return false;
  }

  if (key.expired_at !== null && key.expired_at <= now) {
    return false;
  }

  return true;
}
