import { describe, expect, test } from "vitest";
import { createServiceContext, createUserId } from "./helpers";

describe("plaid exchange", () => {
  test("never returns access tokens and stores encrypted ciphertext", async () => {
    const context = createServiceContext();
    const userId = await createUserId(context);

    const result = await context.plaidService.exchangePublicToken(userId, "public-sandbox");

    expect(result).toEqual({ ok: true });
    expect(JSON.stringify(result)).not.toContain("access-sandbox");
    expect(JSON.stringify(result)).not.toContain("access_token");

    const item = await context.repositories.plaidItems.findByItemId("item-sandbox");
    expect(item).not.toBeNull();
    expect(item?.accessTokenEnc).not.toBe("access-sandbox");
    expect(item?.accessTokenEnc).not.toContain("access-sandbox");
    expect(context.tokenCrypto.decrypt(item?.accessTokenEnc ?? "")).toBe("access-sandbox");

    const accounts = await context.repositories.accounts.listByUser(userId);
    expect(accounts).toEqual([
      expect.objectContaining({
        name: "Everyday Checking",
        mask: "1234"
      })
    ]);
  });
});
