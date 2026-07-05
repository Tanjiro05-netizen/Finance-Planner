import { describe, expect, test } from "vitest";
import { createServiceContext, createUserId } from "./helpers";

describe("plaid webhook", () => {
  test("rejects invalid signatures and marks valid item webhooks for sync", async () => {
    const invalidContext = createServiceContext({
      webhookVerifier: {
        async verify() {
          return false;
        }
      }
    });

    await expect(
      invalidContext.plaidService.verifyWebhook("bad-signature", Buffer.from("{}"))
    ).resolves.toBe(false);

    const validContext = createServiceContext({
      webhookVerifier: {
        async verify() {
          return true;
        }
      }
    });
    const userId = await createUserId(validContext);
    await validContext.plaidService.exchangePublicToken(userId, "public-sandbox");

    await expect(
      validContext.plaidService.verifyWebhook("valid-signature", Buffer.from("{}"))
    ).resolves.toBe(true);
    await validContext.plaidService.markItemNeedsSync("item-sandbox");

    const item = await validContext.repositories.plaidItems.findByItemId("item-sandbox");
    expect(item?.status).toBe("needs_sync");
  });
});
