import { describe, expect, test } from "vitest";
import { TokenCrypto } from "../src/services/crypto";

describe("TokenCrypto", () => {
  test("round trips tokens without storing plaintext", () => {
    const crypto = new TokenCrypto(Buffer.alloc(32, 7).toString("base64"));
    const ciphertext = crypto.encrypt("access-secret");

    expect(ciphertext).not.toContain("access-secret");
    expect(ciphertext).not.toBe("access-secret");
    expect(crypto.decrypt(ciphertext)).toBe("access-secret");
  });
});
