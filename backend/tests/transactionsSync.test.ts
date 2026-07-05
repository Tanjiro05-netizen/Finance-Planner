import { describe, expect, test } from "vitest";
import type {
  TransactionsSyncRequest,
  TransactionsSyncResponse
} from "../src/services/plaidClient";
import { createServiceContext, createUserId } from "./helpers";

describe("transactions sync", () => {
  test("advances cursors and does not duplicate transactions on re-sync", async () => {
    const context = createServiceContext({
      plaidClient: {
        transactionsSync: async (request: TransactionsSyncRequest) => ({
          data: syncResponse(request.cursor)
        })
      }
    });
    const userId = await createUserId(context);

    await context.plaidService.exchangePublicToken(userId, "public-sandbox");

    await expect(context.plaidService.syncTransactions(userId)).resolves.toEqual({
      added: 1,
      modified: 0,
      removed: 0,
      hasMore: false
    });
    await expect(context.plaidService.syncTransactions(userId)).resolves.toEqual({
      added: 0,
      modified: 0,
      removed: 0,
      hasMore: false
    });

    const transactions = await context.repositories.transactions.listByUser({
      userId,
      limit: 50,
      offset: 0
    });
    expect(transactions).toHaveLength(1);
    expect(transactions[0]?.plaidTxnId).toBe("txn-1");

    const item = await context.repositories.plaidItems.findByItemId("item-sandbox");
    expect(item?.cursor).toBe("cursor-1");
  });
});

function syncResponse(cursor: string | undefined): TransactionsSyncResponse {
  if (cursor === "cursor-1") {
    return {
      accounts: [],
      added: [],
      modified: [],
      removed: [],
      next_cursor: "cursor-1",
      has_more: false
    };
  }

  return {
    accounts: [
      {
        account_id: "account-sandbox",
        mask: "1234",
        name: "Everyday Checking",
        type: "depository"
      }
    ],
    added: [
      {
        account_id: "account-sandbox",
        amount: 15.49,
        iso_currency_code: "USD",
        unofficial_currency_code: null,
        date: "2026-06-01",
        name: "Streambox",
        merchant_name: "Streambox",
        pending: false,
        transaction_id: "txn-1",
        category: ["Service", "Subscription"],
        personal_finance_category: {
          primary: "ENTERTAINMENT"
        }
      }
    ],
    modified: [],
    removed: [],
    next_cursor: "cursor-1",
    has_more: false
  };
}
