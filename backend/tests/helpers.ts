import type { AppConfig } from "../src/config";
import { createMemoryRepositories } from "../src/repositories/memoryRepositories";
import type { SiftRepositories } from "../src/repositories/types";
import { AuthService } from "../src/services/authService";
import { CancellationService } from "../src/services/cancellationService";
import { TokenCrypto } from "../src/services/crypto";
import type {
  AccountsGetResponse,
  InstitutionsGetByIdResponse,
  ItemPublicTokenExchangeResponse,
  LinkTokenCreateResponse,
  PlaidClient,
  TransactionsSyncResponse,
  WebhookVerificationKeyGetResponse
} from "../src/services/plaidClient";
import { PlaidService } from "../src/services/plaidService";
import type { WebhookVerifier } from "../src/services/webhookVerifier";

export type ServiceContext = {
  repositories: SiftRepositories;
  authService: AuthService;
  cancellationService: CancellationService;
  plaidClient: PlaidClient;
  plaidService: PlaidService;
  tokenCrypto: TokenCrypto;
};

export function createServiceContext(options: {
  plaidClient?: Partial<PlaidClient>;
  webhookVerifier?: WebhookVerifier;
  conciergeEnabled?: boolean;
} = {}): ServiceContext {
  const repositories = createMemoryRepositories();
  const plaidClient = createFakePlaidClient(options.plaidClient);
  const tokenCrypto = new TokenCrypto(testConfig.tokenEncryptionKey);
  const authService = new AuthService(
    repositories,
    testConfig.jwtSecret,
    testConfig.jwtTtlSeconds
  );
  const plaidService = new PlaidService(
    plaidClient,
    repositories,
    tokenCrypto,
    {
      clientName: testConfig.plaid.clientName,
      webhookUrl: testConfig.plaid.webhookUrl
    },
    options.webhookVerifier ?? {
      async verify() {
        return true;
      }
    }
  );

  return {
    repositories,
    authService,
    cancellationService: new CancellationService(repositories, {
      conciergeEnabled: options.conciergeEnabled ?? true
    }),
    plaidClient,
    plaidService,
    tokenCrypto
  };
}

export const testConfig: AppConfig = {
  nodeEnv: "test",
  port: 0,
  databaseUrl: "postgresql://sift:sift@localhost:5432/sift_test",
  jwtSecret: "test-jwt-secret-at-least-thirty-two-bytes",
  jwtTtlSeconds: 3_600,
  tokenEncryptionKey: Buffer.alloc(32, 7).toString("base64"),
  features: {
    conciergeEnabled: true
  },
  plaid: {
    env: "sandbox",
    clientId: "test-client-id",
    secret: "test-secret",
    clientName: "Sift",
    webhookUrl: "https://example.test/v1/webhook/plaid"
  }
};

export function createFakePlaidClient(overrides: Partial<PlaidClient> = {}): PlaidClient {
  return {
    linkTokenCreate: async () =>
      plaidData<LinkTokenCreateResponse>({
        link_token: "link-sandbox"
      }),
    itemPublicTokenExchange: async () =>
      plaidData<ItemPublicTokenExchangeResponse>({
        access_token: "access-sandbox",
        item_id: "item-sandbox"
      }),
    itemRemove: async () => plaidData({ request_id: "remove-request" }),
    accountsGet: async () =>
      plaidData<AccountsGetResponse>({
        accounts: [
          {
            account_id: "account-sandbox",
            mask: "1234",
            name: "Everyday Checking",
            type: "depository"
          }
        ],
        item: {
          institution_id: "ins_sandbox"
        }
      }),
    transactionsSync: async () =>
      plaidData<TransactionsSyncResponse>({
        accounts: [],
        added: [],
        modified: [],
        removed: [],
        next_cursor: "cursor-empty",
        has_more: false
      }),
    institutionsGetById: async () =>
      plaidData<InstitutionsGetByIdResponse>({
        institution: {
          name: "Sandbox Bank"
        }
      }),
    webhookVerificationKeyGet: async () =>
      plaidData<WebhookVerificationKeyGetResponse>({
        key: {
          alg: "ES256",
          crv: "P-256",
          kid: "kid",
          kty: "EC",
          use: "sig",
          x: "",
          y: "",
          created_at: 0,
          expired_at: null
        }
      }),
    ...overrides
  };
}

export async function createUserId(context: ServiceContext): Promise<string> {
  const { token } = await context.authService.bootstrap();
  return context.authService.verifyToken(token);
}

function plaidData<T>(data: unknown): Promise<{ data: T }> {
  return Promise.resolve({ data: data as T });
}
