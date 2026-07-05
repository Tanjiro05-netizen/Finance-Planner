export type PlaidItemStatus = "active" | "needs_sync" | "error";
export type CancellationMethod = "concierge" | "guided";
export type CancellationStatus =
  | "requested"
  | "contacting"
  | "confirmed"
  | "needsUser"
  | "cancelledByUser";

export type UserRecord = {
  id: string;
  createdAt: Date;
};

export type PlaidItemRecord = {
  id: string;
  userId: string;
  accessTokenEnc: string;
  itemId: string;
  institutionName: string;
  cursor: string | null;
  status: PlaidItemStatus;
  createdAt: Date;
};

export type AccountRecord = {
  id: string;
  userId: string;
  plaidItemId: string;
  plaidAccountId: string;
  mask: string | null;
  name: string;
  type: string;
};

export type TransactionRecord = {
  id: string;
  userId: string;
  accountId: string;
  plaidTxnId: string;
  merchantName: string;
  amountMinor: number;
  isoCurrency: string;
  date: Date;
  pending: boolean;
  category: string | null;
};

export type CancellationRequestRecord = {
  id: string;
  userId: string;
  subscriptionRef: string;
  merchantName: string;
  method: CancellationMethod;
  status: CancellationStatus;
  note: string | null;
  createdAt: Date;
  updatedAt: Date;
};

export type UpsertPlaidItemInput = {
  userId: string;
  accessTokenEnc: string;
  itemId: string;
  institutionName: string;
};

export type UpsertAccountInput = {
  userId: string;
  plaidItemId: string;
  plaidAccountId: string;
  mask: string | null;
  name: string;
  type: string;
};

export type UpsertTransactionInput = {
  userId: string;
  accountId: string;
  plaidTxnId: string;
  merchantName: string;
  amountMinor: number;
  isoCurrency: string;
  date: Date;
  pending: boolean;
  category: string | null;
};

export type ListTransactionsInput = {
  userId: string;
  since?: Date;
  limit: number;
  offset: number;
};

export type CreateCancellationInput = {
  userId: string;
  subscriptionRef: string;
  merchantName: string;
  method: CancellationMethod;
};

export type AdvanceCancellationInput = {
  userId: string;
  id: string;
  status: Exclude<CancellationStatus, "requested">;
  note?: string;
};

export type UserRepository = {
  create(): Promise<UserRecord>;
  findById(id: string): Promise<UserRecord | null>;
  deleteById(id: string): Promise<boolean>;
};

export type PlaidItemRepository = {
  upsertLinkedItem(input: UpsertPlaidItemInput): Promise<PlaidItemRecord>;
  listByUser(userId: string): Promise<PlaidItemRecord[]>;
  findByItemId(itemId: string): Promise<PlaidItemRecord | null>;
  updateCursor(id: string, cursor: string | null, status: PlaidItemStatus): Promise<void>;
  markNeedsSyncByItemId(itemId: string): Promise<boolean>;
  deleteByIdForUser(userId: string, id: string): Promise<PlaidItemRecord | null>;
};

export type AccountRepository = {
  upsertMany(accounts: UpsertAccountInput[]): Promise<AccountRecord[]>;
  listByUser(userId: string): Promise<AccountRecord[]>;
  findByPlaidAccountId(plaidItemId: string, plaidAccountId: string): Promise<AccountRecord | null>;
};

export type TransactionRepository = {
  upsertMany(transactions: UpsertTransactionInput[]): Promise<TransactionRecord[]>;
  deleteByPlaidTxnIds(userId: string, plaidTxnIds: string[]): Promise<number>;
  listByUser(input: ListTransactionsInput): Promise<TransactionRecord[]>;
};

export type CancellationRepository = {
  create(input: CreateCancellationInput): Promise<CancellationRequestRecord>;
  listByUser(userId: string): Promise<CancellationRequestRecord[]>;
  advance(input: AdvanceCancellationInput): Promise<CancellationRequestRecord | null>;
};

export type SiftRepositories = {
  users: UserRepository;
  plaidItems: PlaidItemRepository;
  accounts: AccountRepository;
  transactions: TransactionRepository;
  cancellations: CancellationRepository;
};
