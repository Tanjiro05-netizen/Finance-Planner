import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto";
import { badRequest } from "../errors";

const VERSION = "v1";
const IV_BYTES = 12;
const TAG_BYTES = 16;

export class TokenCrypto {
  private readonly key: Buffer;

  constructor(rawKey: string) {
    this.key = parseKey(rawKey);
  }

  encrypt(plaintext: string): string {
    const iv = randomBytes(IV_BYTES);
    const cipher = createCipheriv("aes-256-gcm", this.key, iv, {
      authTagLength: TAG_BYTES
    });
    const ciphertext = Buffer.concat([
      cipher.update(plaintext, "utf8"),
      cipher.final()
    ]);
    const tag = cipher.getAuthTag();

    return [
      VERSION,
      iv.toString("base64url"),
      tag.toString("base64url"),
      ciphertext.toString("base64url")
    ].join(":");
  }

  decrypt(ciphertext: string): string {
    const [version, ivPart, tagPart, encryptedPart] = ciphertext.split(":");

    if (version !== VERSION || !ivPart || !tagPart || !encryptedPart) {
      throw badRequest("invalid_ciphertext", "Stored token ciphertext is invalid.");
    }

    const decipher = createDecipheriv(
      "aes-256-gcm",
      this.key,
      Buffer.from(ivPart, "base64url"),
      { authTagLength: TAG_BYTES }
    );
    decipher.setAuthTag(Buffer.from(tagPart, "base64url"));

    return Buffer.concat([
      decipher.update(Buffer.from(encryptedPart, "base64url")),
      decipher.final()
    ]).toString("utf8");
  }
}

function parseKey(rawKey: string): Buffer {
  const trimmed = rawKey.trim();
  const candidates = [
    Buffer.from(trimmed, "base64"),
    /^[0-9a-fA-F]{64}$/.test(trimmed) ? Buffer.from(trimmed, "hex") : Buffer.alloc(0),
    Buffer.from(trimmed, "utf8")
  ];
  const key = candidates.find((candidate) => candidate.length === 32);

  if (!key) {
    throw new Error("TOKEN_ENCRYPTION_KEY must decode to exactly 32 bytes.");
  }

  return key;
}
