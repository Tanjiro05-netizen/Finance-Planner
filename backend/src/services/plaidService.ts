import { internal, notFound } from "../errors";
import type {
  AccountRecord,
  PlaidItemRecord,
  SiftRepositories,
  UpsertAccountInput,
  UpsertTransactionInput
} from "../repositories/types";
import type { TokenCrypto } from "./crypto";
import type { PlaidAccount, PlaidClient, PlaidTransaction } from "./plaidClient";
import type { WebhookVerifier } from "./webhookVerifier";

const COUNTRY_US = "US";
const PRODUCT_TRANSACTIONS = "transactions";

export type SyncCounts = {
  added: number;
  modified: number;
  removed: number;
  hasMore: boolean;
};

export class PlaidService {
  constructor(
    private readonly plaidClient: PlaidClient,
    private readonly repositories: SiftRepositories,
    private readonly tokenCrypto: TokenCrypto,
    private readonly options: {
      clientName: string;
      webhookUrl?: string;
    },
    private readonly webhookVerifier: WebhookVerifier
  ) {}

  async createLinkToken(userId: string): Promise<{ link_token: string }> {
    const response = await this.plaidClient.linkTokenCreate({
      client_name: this.options.clientName,
      country_codes: [COUNTRY_US],
      language: "en",
      products: [PRODUCT_TRANSACTIONS],
      user: {
        client_user_id: userId
      },
      ...(this.options.webhookUrl ? { webhook: this.options.webhookUrl } : {})
    });

    return { link_token: response.data.link_token };
  }

  async exchangePublicToken(userId: string, publicToken: string): Promise<{ ok: true }> {
    const exchangeResponse = await this.plaidClient.itemPublicTokenExchange({
      public_token: publicToken
    });
    const accessToken = exchangeResponse.data.access_token;
    const accountsResponse = await this.plaidClient.accountsGet({
      access_token: accessToken
    });
    const institutionName = await this.resolveInstitutionName(
      accountsResponse.data.item.institution_id
    );
    const plaidItem = await this.repositories.plaidItems.upsertLinkedItem({
      userId,
      accessTokenEnc: this.tokenCrypto.encrypt(accessToken),
      itemId: exchangeResponse.data.item_id,
      institutionName
    });

    await this.repositories.accounts.upsertMany(
      accountsResponse.data.accounts.map((account) =>
        mapPlaidAccount(userId, plaidItem.id, account)
      )
    );

    return { ok: true };
  }

  async syncTransactions(userId: string): Promise<SyncCounts> {
    const items = await this.repositories.plaidItems.listByUser(userId);
    const totals: SyncCounts = {
      added: 0,
      modified: 0,
      removed: 0,
      hasMore: false
    };

    for (const item of items) {
      const itemCounts = await this.syncItem(item);
      totals.added += itemCounts.added;
      totals.modified += itemCounts.modified;
      totals.removed += itemCounts.removed;
      totals.hasMore = totals.hasMore || itemCounts.hasMore;
    }

    return totals;
  }

  async verifyWebhook(signature: string, rawBody: Buffer): Promise<boolean> {
    return this.webhookVerifier.verify(signature, rawBody);
  }

  async markItemNeedsSync(itemId: string | undefined): Promise<{ ok: true }> {
    if (itemId) {
      await this.repositories.plaidItems.markNeedsSyncByItemId(itemId);
    }

    return { ok: true };
  }

  async removeLinkedItem(userId: string, plaidItemId: string): Promise<{ ok: true }> {
    const item = (await this.repositories.plaidItems.listByUser(userId)).find(
      (candidate) => candidate.id === plaidItemId
    );

    if (!item) {
      throw notFound("Linked item was not found.");
    }

    await this.revokeItem(item);
    await this.repositories.plaidItems.deleteByIdForUser(userId, plaidItemId);
    return { ok: true };
  }

  async deleteUserData(userId: string): Promise<{ ok: true }> {
    const items = await this.repositories.plaidItems.listByUser(userId);

    for (const item of items) {
      await this.revokeItem(item);
    }

    await this.repositories.users.deleteById(userId);
    return { ok: true };
  }

  private async syncItem(item: PlaidItemRecord): Promise<SyncCounts> {
    const accessToken = this.tokenCrypto.decrypt(item.accessTokenEnc);
    let cursor = item.cursor ?? undefined;
    let hasMore = false;
    const counts: SyncCounts = {
      added: 0,
      modified: 0,
      removed: 0,
      hasMore: false
    };

    do {
      const response = await this.plaidClient.transactionsSync({
        access_token: accessToken,
        cursor,
        count: 500,
        options: {
          days_requested: 180
        }
      });
      const data = response.data;

      await this.repositories.accounts.upsertMany(
        data.accounts.map((account) => mapPlaidAccount(item.userId, item.id, account))
      );
      await this.upsertTransactions(item, data.added);
      await this.upsertTransactions(item, data.modified);
      await this.repositories.transactions.deleteByPlaidTxnIds(
        item.userId,
        data.removed.map((transaction) => transaction.transaction_id)
      );

      counts.added += data.added.length;
      counts.modified += data.modified.length;
      counts.removed += data.removed.length;
      cursor = data.next_cursor || cursor;
      hasMore = data.has_more;
      counts.hasMore = hasMore;
    } while (hasMore);

    await this.repositories.plaidItems.updateCursor(item.id, cursor ?? null, "active");
    return counts;
  }

  private async revokeItem(item: PlaidItemRecord): Promise<void> {
    await this.plaidClient.itemRemove({
      access_token: this.tokenCrypto.decrypt(item.accessTokenEnc)
    });
  }

  private async upsertTransactions(
    item: PlaidItemRecord,
    transactions: PlaidTransaction[]
  ): Promise<void> {
    const mapped: UpsertTransactionInput[] = [];

    for (const transaction of transactions) {
      const account = await this.repositories.accounts.findByPlaidAccountId(
        item.id,
        transaction.account_id
      );

      if (!account) {
        throw internal("Plaid returned a transaction for an unknown account.");
      }

      mapped.push(mapPlaidTransaction(item.userId, account, transaction));
    }

    if (mapped.length > 0) {
      await this.repositories.transactions.upsertMany(mapped);
    }
  }

  private async resolveInstitutionName(institutionId: string | null | undefined): Promise<string> {
    if (!institutionId) {
      return "Linked institution";
    }

    try {
      const response = await this.plaidClient.institutionsGetById({
        institution_id: institutionId,
        country_codes: [COUNTRY_US]
      });
      return response.data.institution.name;
    } catch {
      return "Linked institution";
    }
  }
}

function mapPlaidAccount(
  userId: string,
  plaidItemId: string,
  account: PlaidAccount
): UpsertAccountInput {
  return {
    userId,
    plaidItemId,
    plaidAccountId: account.account_id,
    mask: account.mask,
    name: account.name,
    type: account.type
  };
}

function mapPlaidTransaction(
  userId: string,
  account: AccountRecord,
  transaction: PlaidTransaction
): UpsertTransactionInput {
  return {
    userId,
    accountId: account.id,
    plaidTxnId: transaction.transaction_id,
    merchantName: transaction.merchant_name ?? transaction.name,
    amountMinor: Math.round(transaction.amount * 100),
    isoCurrency:
      transaction.iso_currency_code ?? transaction.unofficial_currency_code ?? "USD",
    date: new Date(`${transaction.date}T00:00:00.000Z`),
    pending: transaction.pending,
    category:
      transaction.personal_finance_category?.primary ??
      transaction.category?.join(" > ") ??
      null
  };
}
