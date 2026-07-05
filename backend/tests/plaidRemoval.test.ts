import { describe, expect, test } from "vitest";
import type {
  ItemRemoveRequest,
  TransactionsSyncRequest,
  TransactionsSyncResponse
} from "../src/services/plaidClient";
import { createServiceContext, createUserId } from "./helpers";

describe("plaid item removal", () => {
  test("revokes one linked item and removes its local accounts and transactions", async () => {
    const removedTokens: string[] = [];
    const context = createServiceContext({
      plaidClient: {
        itemRemove: async (request: ItemRemoveRequest) => {
          removedTokens.push(request.access_token);
          return { data: { request_id: "remove-one" } };
        },
        transactionsSync: async (request: TransactionsSyncRequest) => ({
          data: transactionSyncResponse(request.cursor)
        })
      }
    });
    const userId = await createUserId(context);

    await context.plaidService.exchangePublicToken(userId, "public-sandbox");
    await context.plaidService.syncTransactions(userId);
    const item = await context.repositories.plaidItems.findByItemId("item-sandbox");

    await context.plaidService.removeLinkedItem(userId, item?.id ?? "");

    expect(removedTokens).toEqual(["access-sandbox"]);
    await expect(context.repositories.plaidItems.listByUser(userId)).resolves.toEqual([]);
    await expect(context.repositories.accounts.listByUser(userId)).resolves.toEqual([]);
    await expect(
      context.repositories.transactions.listByUser({ userId, limit: 50, offset: 0 })
    ).resolves.toEqual([]);
  });

  test("delete user data revokes all items and invalidates the session", async () => {
    const removedTokens: string[] = [];
    let exchangeCount = 0;
    const context = createServiceContext({
      plaidClient: {
        itemPublicTokenExchange: async () => {
          exchangeCount += 1;
          return {
            data: {
              access_token: `access-sandbox-${exchangeCount}`,
              item_id: `item-sandbox-${exchangeCount}`
            }
          };
        },
        itemRemove: async (request: ItemRemoveRequest) => {
          removedTokens.push(request.access_token);
          return { data: { request_id: "remove-all" } };
        }
      }
    });
    const userAId = await createUserId(context);
    const userBId = await createUserId(context);

    await context.plaidService.exchangePublicToken(userAId, "public-a");
    await context.plaidService.exchangePublicToken(userBId, "public-b");

    await context.plaidService.deleteUserData(userAId);

    expect(removedTokens).toEqual(["access-sandbox-1"]);
    await expect(context.repositories.users.findById(userAId)).resolves.toBeNull();
    await expect(context.repositories.plaidItems.listByUser(userAId)).resolves.toEqual([]);
    await expect(context.repositories.plaidItems.listByUser(userBId)).resolves.toHaveLength(1);
  });
});

function transactionSyncResponse(cursor: string | undefined): TransactionsSyncResponse {
  if (cursor) {
    return {
      accounts: [],
      added: [],
      modified: [],
      removed: [],
      next_cursor: cursor,
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
        transaction_id: "txn-remove-1",
        category: ["Service", "Subscription"],
        personal_finance_category: {
          primary: "ENTERTAINMENT"
        }
      }
    ],
    modified: [],
    removed: [],
    next_cursor: "cursor-remove",
    has_more: false
  };
}
