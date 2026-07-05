import { conflict } from "../errors";
import type {
  AdvanceCancellationInput,
  CancellationMethod,
  CancellationRequestRecord,
  CancellationStatus,
  CreateCancellationInput,
  ListTransactionsInput,
  PlaidItemRecord,
  PlaidItemStatus,
  SiftRepositories,
  UpsertAccountInput,
  UpsertPlaidItemInput,
  UpsertTransactionInput,
  UserRecord
} from "./types";

type PrismaDelegate = {
  create(args: any): Promise<any>;
  delete(args: any): Promise<any>;
  findUnique(args: any): Promise<any | null>;
  findFirst(args: any): Promise<any | null>;
  findMany(args: any): Promise<any[]>;
  update(args: any): Promise<any>;
  upsert(args: any): Promise<any>;
  deleteMany(args: any): Promise<{ count: number }>;
};

export type PrismaRuntimeClient = {
  user: Pick<PrismaDelegate, "create" | "findUnique" | "delete">;
  plaidItem: Pick<
    PrismaDelegate,
    "create" | "delete" | "findUnique" | "findMany" | "update"
  >;
  account: Pick<PrismaDelegate, "upsert" | "findMany" | "findUnique">;
  transaction: Pick<PrismaDelegate, "upsert" | "findMany" | "deleteMany">;
  cancellationRequest: Pick<
    PrismaDelegate,
    "create" | "findMany" | "findFirst" | "update"
  >;
  $queryRaw<T = unknown>(
    query: TemplateStringsArray,
    ...values: unknown[]
  ): Promise<T>;
  $disconnect(): Promise<void>;
};

type PrismaClientConstructor = new () => PrismaRuntimeClient;

export function createPrismaClient(): PrismaRuntimeClient {
  const { PrismaClient } = loadPrismaClient("@prisma/client");
  return new PrismaClient();
}

function loadPrismaClient(moduleName: string): { PrismaClient: PrismaClientConstructor } {
  const runtimeRequire = eval("require") as (name: string) => unknown;
  return runtimeRequire(moduleName) as { PrismaClient: PrismaClientConstructor };
}

export function createPrismaRepositories(prisma: PrismaRuntimeClient): SiftRepositories {
  return {
    users: {
      async create() {
        return prisma.user.create({ data: {} }) as Promise<UserRecord>;
      },
      async findById(id) {
        return prisma.user.findUnique({ where: { id } }) as Promise<UserRecord | null>;
      },
      async deleteById(id) {
        const existing = await prisma.user.findUnique({ where: { id } });

        if (!existing) {
          return false;
        }

        await prisma.user.delete({ where: { id } });
        return true;
      }
    },
    plaidItems: {
      async upsertLinkedItem(input: UpsertPlaidItemInput) {
        const existing = (await prisma.plaidItem.findUnique({
          where: { itemId: input.itemId }
        })) as PlaidItemRecord | null;

        if (existing && existing.userId !== input.userId) {
          throw conflict("Plaid item is already linked to a different user.");
        }

        const item = existing
          ? await prisma.plaidItem.update({
              where: { id: existing.id },
              data: {
                accessTokenEnc: input.accessTokenEnc,
                institutionName: input.institutionName,
                status: "active"
              }
            })
          : await prisma.plaidItem.create({
              data: {
                userId: input.userId,
                accessTokenEnc: input.accessTokenEnc,
                itemId: input.itemId,
                institutionName: input.institutionName,
                status: "active"
              }
            });

        return mapPlaidItem(item);
      },
      async listByUser(userId) {
        const items = await prisma.plaidItem.findMany({
          where: { userId },
          orderBy: { createdAt: "asc" }
        });
        return items.map(mapPlaidItem);
      },
      async findByItemId(itemId) {
        const item = await prisma.plaidItem.findUnique({ where: { itemId } });
        return item ? mapPlaidItem(item) : null;
      },
      async updateCursor(id, cursor, status) {
        await prisma.plaidItem.update({
          where: { id },
          data: {
            cursor,
            status
          }
        });
      },
      async markNeedsSyncByItemId(itemId) {
        const item = (await prisma.plaidItem.findUnique({
          where: { itemId }
        })) as PlaidItemRecord | null;

        if (!item) {
          return false;
        }

        await prisma.plaidItem.update({
          where: { id: item.id },
          data: { status: "needs_sync" }
        });
        return true;
      },
      async deleteByIdForUser(userId, id) {
        const item = await prisma.plaidItem.findUnique({ where: { id } });

        if (!item || item.userId !== userId) {
          return null;
        }

        await prisma.plaidItem.delete({ where: { id } });
        return mapPlaidItem(item);
      }
    },
    accounts: {
      async upsertMany(inputs: UpsertAccountInput[]) {
        return Promise.all(
          inputs.map((input) =>
            prisma.account.upsert({
              where: {
                plaidItemId_plaidAccountId: {
                  plaidItemId: input.plaidItemId,
                  plaidAccountId: input.plaidAccountId
                }
              },
              create: input,
              update: {
                mask: input.mask,
                name: input.name,
                type: input.type
              }
            })
          )
        );
      },
      async listByUser(userId) {
        return prisma.account.findMany({
          where: { userId },
          orderBy: { name: "asc" }
        });
      },
      async findByPlaidAccountId(plaidItemId, plaidAccountId) {
        return prisma.account.findUnique({
          where: {
            plaidItemId_plaidAccountId: {
              plaidItemId,
              plaidAccountId
            }
          }
        });
      }
    },
    transactions: {
      async upsertMany(inputs: UpsertTransactionInput[]) {
        return Promise.all(
          inputs.map((input) =>
            prisma.transaction.upsert({
              where: { plaidTxnId: input.plaidTxnId },
              create: input,
              update: {
                accountId: input.accountId,
                merchantName: input.merchantName,
                amountMinor: input.amountMinor,
                isoCurrency: input.isoCurrency,
                date: input.date,
                pending: input.pending,
                category: input.category
              }
            })
          )
        );
      },
      async deleteByPlaidTxnIds(userId, plaidTxnIds) {
        const result = await prisma.transaction.deleteMany({
          where: {
            userId,
            plaidTxnId: { in: plaidTxnIds }
          }
        });
        return result.count;
      },
      async listByUser(input: ListTransactionsInput) {
        return prisma.transaction.findMany({
          where: {
            userId: input.userId,
            ...(input.since ? { date: { gte: input.since } } : {})
          },
          orderBy: [{ date: "desc" }, { id: "desc" }],
          take: input.limit,
          skip: input.offset
        });
      }
    },
    cancellations: {
      async create(input: CreateCancellationInput) {
        const request = await prisma.cancellationRequest.create({
          data: {
            userId: input.userId,
            subscriptionRef: input.subscriptionRef,
            merchantName: input.merchantName,
            method: input.method
          }
        });
        return mapCancellation(request);
      },
      async listByUser(userId) {
        const requests = await prisma.cancellationRequest.findMany({
          where: { userId },
          orderBy: { createdAt: "desc" }
        });
        return requests.map(mapCancellation);
      },
      async advance(input: AdvanceCancellationInput) {
        const existing = await prisma.cancellationRequest.findFirst({
          where: {
            id: input.id,
            userId: input.userId
          }
        });

        if (!existing) {
          return null;
        }

        const request = await prisma.cancellationRequest.update({
          where: { id: input.id },
          data: {
            status: input.status,
            ...(input.note ? { note: input.note } : {})
          }
        });
        return mapCancellation(request);
      }
    }
  };
}

function mapPlaidItem(item: Record<string, unknown>): PlaidItemRecord {
  return {
    id: item.id as string,
    userId: item.userId as string,
    accessTokenEnc: item.accessTokenEnc as string,
    itemId: item.itemId as string,
    institutionName: item.institutionName as string,
    cursor: (item.cursor as string | null) ?? null,
    status: item.status as PlaidItemStatus,
    createdAt: item.createdAt as Date
  };
}

function mapCancellation(item: Record<string, unknown>): CancellationRequestRecord {
  return {
    id: item.id as string,
    userId: item.userId as string,
    subscriptionRef: item.subscriptionRef as string,
    merchantName: item.merchantName as string,
    method: item.method as CancellationMethod,
    status: item.status as CancellationStatus,
    note: (item.note as string | null) ?? null,
    createdAt: item.createdAt as Date,
    updatedAt: item.updatedAt as Date
  };
}
