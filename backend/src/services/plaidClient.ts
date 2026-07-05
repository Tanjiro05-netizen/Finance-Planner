import type { AppConfig } from "../config";

export type PlaidEnvironment = "sandbox" | "development" | "production";

export type LinkTokenCreateRequest = {
  client_name: string;
  country_codes: string[];
  language: string;
  products: string[];
  user: {
    client_user_id: string;
  };
  webhook?: string;
};

export type LinkTokenCreateResponse = {
  link_token: string;
};

export type ItemPublicTokenExchangeRequest = {
  public_token: string;
};

export type ItemPublicTokenExchangeResponse = {
  access_token: string;
  item_id: string;
};

export type PlaidAccount = {
  account_id: string;
  mask: string | null;
  name: string;
  type: string;
};

export type AccountsGetRequest = {
  access_token: string;
};

export type ItemRemoveRequest = {
  access_token: string;
};

export type ItemRemoveResponse = {
  request_id?: string;
};

export type AccountsGetResponse = {
  accounts: PlaidAccount[];
  item: {
    institution_id?: string | null;
  };
};

export type InstitutionsGetByIdRequest = {
  institution_id: string;
  country_codes: string[];
};

export type InstitutionsGetByIdResponse = {
  institution: {
    name: string;
  };
};

export type PlaidTransaction = {
  account_id: string;
  amount: number;
  category?: string[] | null;
  date: string;
  iso_currency_code?: string | null;
  merchant_name?: string | null;
  name: string;
  pending: boolean;
  personal_finance_category?: {
    primary?: string | null;
  } | null;
  transaction_id: string;
  unofficial_currency_code?: string | null;
};

export type RemovedPlaidTransaction = {
  transaction_id: string;
};

export type TransactionsSyncRequest = {
  access_token: string;
  cursor?: string;
  count?: number;
  options?: {
    days_requested?: number;
  };
};

export type TransactionsSyncResponse = {
  accounts: PlaidAccount[];
  added: PlaidTransaction[];
  modified: PlaidTransaction[];
  removed: RemovedPlaidTransaction[];
  next_cursor: string;
  has_more: boolean;
};

export type JWKPublicKey = {
  alg: string;
  crv: string;
  kid: string;
  kty: string;
  use: string;
  x: string;
  y: string;
  created_at: number;
  expired_at: number | null;
};

export type WebhookVerificationKeyGetRequest = {
  key_id: string;
};

export type WebhookVerificationKeyGetResponse = {
  key: JWKPublicKey;
};

export type PlaidResponse<T> = Promise<{ data: T }>;

export type PlaidClient = {
  linkTokenCreate(request: LinkTokenCreateRequest): PlaidResponse<LinkTokenCreateResponse>;
  itemPublicTokenExchange(
    request: ItemPublicTokenExchangeRequest
  ): PlaidResponse<ItemPublicTokenExchangeResponse>;
  itemRemove(request: ItemRemoveRequest): PlaidResponse<ItemRemoveResponse>;
  accountsGet(request: AccountsGetRequest): PlaidResponse<AccountsGetResponse>;
  transactionsSync(request: TransactionsSyncRequest): PlaidResponse<TransactionsSyncResponse>;
  institutionsGetById(
    request: InstitutionsGetByIdRequest
  ): PlaidResponse<InstitutionsGetByIdResponse>;
  webhookVerificationKeyGet(
    request: WebhookVerificationKeyGetRequest
  ): PlaidResponse<WebhookVerificationKeyGetResponse>;
};

type PlaidSdkModule = {
  Configuration: new (options: {
    basePath: string;
    baseOptions: {
      headers: Record<string, string>;
    };
  }) => unknown;
  PlaidApi: new (configuration: unknown) => PlaidClient;
  PlaidEnvironments: Record<PlaidEnvironment, string>;
};

export function createPlaidClient(config: AppConfig): PlaidClient {
  const { Configuration, PlaidApi, PlaidEnvironments } = loadPlaidSdk("plaid");
  const configuration = new Configuration({
    basePath: PlaidEnvironments[config.plaid.env],
    baseOptions: {
      headers: {
        "PLAID-CLIENT-ID": config.plaid.clientId,
        "PLAID-SECRET": config.plaid.secret,
        "Plaid-Version": "2020-09-14"
      }
    }
  });

  return new PlaidApi(configuration);
}

function loadPlaidSdk(moduleName: string): PlaidSdkModule {
  const runtimeRequire = eval("require") as (name: string) => unknown;
  return runtimeRequire(moduleName) as PlaidSdkModule;
}
