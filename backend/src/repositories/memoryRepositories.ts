import { randomUUID } from "node:crypto";
import { conflict } from "../errors";
import type {
  AccountRecord,
  AdvanceCancellationInput,
  CancellationRequestRecord,
  CreateCancellationInput,
  ListTransactionsInput,
  PlaidItemRecord,
  PlaidItemStatus,
  SiftRepositories,
  TransactionRecord,
  UpsertAccountInput,
  UpsertPlaidItemInput,
  UpsertTransactionInput,
  UserRecord
} from "./types";

export function createMemoryRepositories(): SiftRepositories {
  const users = new Map<string, UserRecord>();
  const plaidItems = new Map<string, PlaidItemRecord>();
  const accounts = new Map<string, AccountRecord>();
  const transactions = new Map<string, TransactionRecord>();
  const cancellations = new Map<string, CancellationRequestRecord>();

  return {
    users: {
      async create() {
        const user = {
          id: randomUUID(),
          createdAt: new Date()
        };
        users.set(user.id, user);
        return user;
      },
      async findById(id) {
        return users.get(id) ?? null;
      },
      async deleteById(id) {
        if (!users.has(id)) {
          return false;
        }

        users.delete(id);

        for (const item of plaidItems.values()) {
          if (item.userId === id) {
            plaidItems.delete(item.id);
          }
        }
        for (const account of accounts.values()) {
          if (account.userId === id) {
            accounts.delete(account.id);
          }
        }
        for (const transaction of transactions.values()) {
          if (transaction.userId === id) {
            transactions.delete(transaction.id);
          }
        }
        for (const request of cancellations.values()) {
          if (request.userId === id) {
            cancellations.delete(request.id);
          }
        }

        return true;
      }
    },
    plaidItems: {
      async upsertLinkedItem(input: UpsertPlaidItemInput) {
        const existing = [...plaidItems.values()].find((item) => item.itemId === input.itemId);

        if (existing && existing.userId !== input.userId) {
          throw conflict("Plaid item is already linked to a different user.");
        }

        const record: PlaidItemRecord = {
          id: existing?.id ?? randomUUID(),
          userId: input.userId,
          accessTokenEnc: input.accessTokenEnc,
          itemId: input.itemId,
          institutionName: input.institutionName,
          cursor: existing?.cursor ?? null,
          status: "active",
          createdAt: existing?.createdAt ?? new Date()
        };
        plaidItems.set(record.id, record);
        return record;
      },
      async listByUser(userId) {
        return [...plaidItems.values()].filter((item) => item.userId === userId);
      },
      async findByItemId(itemId) {
        return [...plaidItems.values()].find((item) => item.itemId === itemId) ?? null;
      },
      async updateCursor(id: string, cursor: string | null, status: PlaidItemStatus) {
        const item = plaidItems.get(id);

        if (item) {
          plaidItems.set(id, { ...item, cursor, status });
        }
      },
      async markNeedsSyncByItemId(itemId) {
        const item = [...plaidItems.values()].find((candidate) => candidate.itemId === itemId);

        if (!item) {
          return false;
        }

        plaidItems.set(item.id, { ...item, status: "needs_sync" });
        return true;
      },
      async deleteByIdForUser(userId, id) {
        const item = plaidItems.get(id);

        if (!item || item.userId !== userId) {
          return null;
        }

        const accountIds = [...accounts.values()]
          .filter((account) => account.userId === userId && account.plaidItemId === id)
          .map((account) => account.id);

        for (const transaction of transactions.values()) {
          if (transaction.userId === userId && accountIds.includes(transaction.accountId)) {
            transactions.delete(transaction.id);
          }
        }

        for (const account of accounts.values()) {
          if (account.userId === userId && account.plaidItemId === id) {
            accounts.delete(account.id);
          }
        }

        plaidItems.delete(id);
        return item;
      }
    },
    accounts: {
      async upsertMany(inputs: UpsertAccountInput[]) {
        return inputs.map((input) => {
          const existing = [...accounts.values()].find(
            (account) =>
              account.plaidItemId === input.plaidItemId &&
              account.plaidAccountId === input.plaidAccountId
          );
          const record: AccountRecord = {
            id: existing?.id ?? randomUUID(),
            userId: input.userId,
            plaidItemId: input.plaidItemId,
            plaidAccountId: input.plaidAccountId,
            mask: input.mask,
            name: input.name,
            type: input.type
          };
          accounts.set(record.id, record);
          return record;
        });
      },
      async listByUser(userId) {
        return [...accounts.values()].filter((account) => account.userId === userId);
      },
      async findByPlaidAccountId(plaidItemId, plaidAccountId) {
        return (
          [...accounts.values()].find(
            (account) =>
              account.plaidItemId === plaidItemId && account.plaidAccountId === plaidAccountId
          ) ?? null
        );
      }
    },
    transactions: {
      async upsertMany(inputs: UpsertTransactionInput[]) {
        return inputs.map((input) => {
          const existing = [...transactions.values()].find(
            (transaction) => transaction.plaidTxnId === input.plaidTxnId
          );
          const record: TransactionRecord = {
            id: existing?.id ?? randomUUID(),
            ...input
          };
          transactions.set(record.id, record);
          return record;
        });
      },
      async deleteByPlaidTxnIds(userId, plaidTxnIds) {
        let removed = 0;

        for (const transaction of transactions.values()) {
          if (transaction.userId === userId && plaidTxnIds.includes(transaction.plaidTxnId)) {
            transactions.delete(transaction.id);
            removed += 1;
          }
        }

        return removed;
      },
      async listByUser(input: ListTransactionsInput) {
        return [...transactions.values()]
          .filter(
            (transaction) =>
              transaction.userId === input.userId &&
              (!input.since || transaction.date >= input.since)
          )
          .sort((left, right) => right.date.getTime() - left.date.getTime())
          .slice(input.offset, input.offset + input.limit);
      }
    },
    cancellations: {
      async create(input: CreateCancellationInput) {
        const now = new Date();
        const record: CancellationRequestRecord = {
          id: randomUUID(),
          ...input,
          status: "requested",
          note: null,
          createdAt: now,
          updatedAt: now
        };
        cancellations.set(record.id, record);
        return record;
      },
      async listByUser(userId) {
        return [...cancellations.values()]
          .filter((request) => request.userId === userId)
          .sort((left, right) => right.createdAt.getTime() - left.createdAt.getTime());
      },
      async advance(input: AdvanceCancellationInput) {
        const request = cancellations.get(input.id);

        if (!request || request.userId !== input.userId) {
          return null;
        }

        const record: CancellationRequestRecord = {
          ...request,
          status: input.status,
          note: input.note ?? request.note,
          updatedAt: new Date()
        };
        cancellations.set(record.id, record);
        return record;
      }
    }
  };
}
