@preconcurrency import Foundation

protocol HTTPDataLoading: Sendable {
    func loadData(for request: URLRequest) async throws -> HTTPDataResponse
}

struct HTTPDataResponse: Sendable {
    let data: Data
    let statusCode: Int
}

extension URLSession: HTTPDataLoading {
    func loadData(for request: URLRequest) async throws -> HTTPDataResponse {
        let (data, response) = try await data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SiftError.network("The server response was invalid.")
        }

        return HTTPDataResponse(data: data, statusCode: httpResponse.statusCode)
    }
}

protocol SiftAPIClient: Sendable {
    func bootstrap() async throws -> AuthBootstrapResponse
    func createLinkToken() async throws -> LinkTokenResponse
    func exchange(publicToken: String) async throws -> ExchangePublicTokenResponse
    func listAccounts() async throws -> [RemoteAccount]
    func deletePlaidItem(id: String) async throws -> APIOKResponse
    func deleteUserData() async throws -> APIOKResponse
    func syncTransactions() async throws -> TransactionSyncResponse
    func listTransactions(limit: Int, offset: Int) async throws -> [RemoteTransaction]
    func createCancellation(
        subscriptionRef: String,
        merchantName: String,
        method: CancellationMethod
    ) async throws -> RemoteCancellationRequest
    func listCancellations() async throws -> [RemoteCancellationRequest]
    func updateCancellation(
        id: String,
        status: CancellationStatus,
        note: String?
    ) async throws -> RemoteCancellationRequest
}

extension SiftAPIClient {
    func listAccounts() async throws -> [RemoteAccount] {
        []
    }

    func deletePlaidItem(id _: String) async throws -> APIOKResponse {
        APIOKResponse(ok: true)
    }

    func deleteUserData() async throws -> APIOKResponse {
        APIOKResponse(ok: true)
    }
}

struct AuthBootstrapResponse: Codable, Equatable, Sendable {
    let token: String
}

struct LinkTokenResponse: Codable, Equatable, Sendable {
    let linkToken: String

    enum CodingKeys: String, CodingKey {
        case linkToken = "link_token"
    }
}

struct ExchangePublicTokenResponse: Codable, Equatable, Sendable {
    let ok: Bool
}

struct APIOKResponse: Codable, Equatable, Sendable {
    let ok: Bool
}

struct RemoteAccount: Codable, Equatable, Sendable {
    let id: String
    let plaidItemId: String
    let institutionName: String
    let mask: String?
    let name: String
    let type: String
    let status: String
}

extension RemoteAccount {
    init(account: LinkedAccount) {
        id = account.id
        plaidItemId = account.plaidItemID ?? account.id
        institutionName = account.institutionName
        mask = account.mask
        name = account.type
        type = account.type
        status = account.status.remoteValue
    }
}

extension LinkedAccountStatus {
    init(remoteStatus: String) {
        switch remoteStatus {
        case "active", "connected":
            self = .connected
        case "needs_sync", "needsAttention":
            self = .needsAttention
        default:
            self = .disconnected
        }
    }

    var remoteValue: String {
        switch self {
        case .connected:
            "active"
        case .needsAttention:
            "needs_sync"
        case .disconnected:
            "error"
        }
    }
}

extension LinkedAccount {
    convenience init(remote: RemoteAccount, userID: String, syncedAt: Date = Date()) {
        self.init(
            id: remote.id,
            userID: userID,
            plaidItemID: remote.plaidItemId,
            institutionName: remote.institutionName,
            mask: remote.mask ?? "",
            type: remote.type,
            status: LinkedAccountStatus(remoteStatus: remote.status),
            lastSyncedAt: syncedAt
        )
    }
}

struct TransactionSyncResponse: Codable, Equatable, Sendable {
    let added: Int
    let modified: Int
    let removed: Int
    let hasMore: Bool
}

struct RemoteTransaction: Codable, Equatable, Sendable {
    let id: String
    let userId: String
    let accountId: String
    let merchantName: String
    let amountMinor: Int
    let isoCurrency: String
    let date: Date
    let pending: Bool
    let category: String?
}

struct RemoteCancellationRequest: Codable, Equatable, Sendable {
    let id: String
    let userId: String
    let subscriptionRef: String
    let merchantName: String
    let method: CancellationMethod
    let status: CancellationStatus
    let note: String?
    let createdAt: Date
    let updatedAt: Date
}

struct APIRetryPolicy: Equatable, Sendable {
    let maxRetries: Int
    let baseDelayNanoseconds: UInt64

    static let standard = APIRetryPolicy(maxRetries: 2, baseDelayNanoseconds: 250_000_000)
    static let immediate = APIRetryPolicy(maxRetries: 2, baseDelayNanoseconds: 0)
    static let disabled = APIRetryPolicy(maxRetries: 0, baseDelayNanoseconds: 0)

    func delayNanoseconds(for attempt: Int) -> UInt64 {
        guard baseDelayNanoseconds > 0 else {
            return 0
        }

        return baseDelayNanoseconds * UInt64(max(attempt, 1))
    }

    func shouldRetry(statusCode: Int, attempt: Int) -> Bool {
        attempt < maxRetries && (statusCode == 429 || (500..<600).contains(statusCode))
    }
}

final class DefaultSiftAPIClient: SiftAPIClient, @unchecked Sendable {
    private let baseURL: URL
    private let loader: any HTTPDataLoading
    private let tokenStore: any TokenStoring
    private let retryPolicy: APIRetryPolicy
    private let analyticsRecorder: any AnalyticsRecording
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        baseURL: URL = APIConfiguration.defaultBaseURL,
        loader: any HTTPDataLoading = URLSession.shared,
        tokenStore: any TokenStoring = KeychainTokenStore(),
        retryPolicy: APIRetryPolicy = .standard,
        analyticsRecorder: any AnalyticsRecording = NoopAnalyticsRecorder()
    ) {
        self.baseURL = baseURL
        self.loader = loader
        self.tokenStore = tokenStore
        self.retryPolicy = retryPolicy
        self.analyticsRecorder = analyticsRecorder

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func bootstrap() async throws -> AuthBootstrapResponse {
        let response: AuthBootstrapResponse = try await send(
            path: "auth/bootstrap",
            method: "POST",
            body: EmptyRequestBody(),
            requiresAuth: false
        )
        try tokenStore.saveToken(response.token)
        return response
    }

    func createLinkToken() async throws -> LinkTokenResponse {
        try await send(
            path: "plaid/link-token",
            method: "POST",
            body: EmptyRequestBody(),
            requiresAuth: true
        )
    }

    func exchange(publicToken: String) async throws -> ExchangePublicTokenResponse {
        try await send(
            path: "plaid/exchange",
            method: "POST",
            body: PublicTokenRequest(publicToken: publicToken),
            requiresAuth: true
        )
    }

    func listAccounts() async throws -> [RemoteAccount] {
        try await send(
            path: "accounts",
            method: "GET",
            body: EmptyRequestBody(),
            requiresAuth: true
        )
    }

    func deletePlaidItem(id: String) async throws -> APIOKResponse {
        try await send(
            path: "plaid/item/\(id)",
            method: "DELETE",
            body: EmptyRequestBody(),
            requiresAuth: true
        )
    }

    func deleteUserData() async throws -> APIOKResponse {
        try await send(
            path: "privacy/data",
            method: "DELETE",
            body: EmptyRequestBody(),
            requiresAuth: true
        )
    }

    func syncTransactions() async throws -> TransactionSyncResponse {
        try await send(
            path: "transactions/sync",
            method: "POST",
            body: EmptyRequestBody(),
            requiresAuth: true
        )
    }

    func listTransactions(limit: Int, offset: Int) async throws -> [RemoteTransaction] {
        try await send(
            path: "transactions",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset)),
            ],
            body: EmptyRequestBody(),
            requiresAuth: true
        )
    }

    func createCancellation(
        subscriptionRef: String,
        merchantName: String,
        method: CancellationMethod
    ) async throws -> RemoteCancellationRequest {
        try await send(
            path: "cancellations",
            method: "POST",
            body: CreateCancellationRequest(
                subscriptionRef: subscriptionRef,
                merchantName: merchantName,
                method: method
            ),
            requiresAuth: true
        )
    }

    func listCancellations() async throws -> [RemoteCancellationRequest] {
        try await send(
            path: "cancellations",
            method: "GET",
            body: EmptyRequestBody(),
            requiresAuth: true
        )
    }

    func updateCancellation(
        id: String,
        status: CancellationStatus,
        note: String?
    ) async throws -> RemoteCancellationRequest {
        try await send(
            path: "cancellations/\(id)",
            method: "PATCH",
            body: UpdateCancellationRequest(status: status, note: note),
            requiresAuth: true
        )
    }

    private func send<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body,
        requiresAuth: Bool
    ) async throws -> Response {
        try await send(
            path: path,
            method: method,
            queryItems: [],
            body: body,
            requiresAuth: requiresAuth
        )
    }

    private func send<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        body: Body,
        requiresAuth: Bool
    ) async throws -> Response {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components?.url else {
            throw SiftError.network("The request URL was invalid.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if method != "GET" {
            request.httpBody = try encoder.encode(body)
        }

        if requiresAuth {
            guard let token = try tokenStore.readToken() else {
                throw SiftError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let endpointLabel = analyticsEndpointLabel(for: path)
        var lastNetworkError: Error?

        for attempt in 0...retryPolicy.maxRetries {
            let response: HTTPDataResponse

            do {
                response = try await loader.loadData(for: request)
            } catch let error as SiftError {
                lastNetworkError = error
                if attempt < retryPolicy.maxRetries, error.isTransient {
                    analyticsRecorder.record(.apiRetry(
                        method: method,
                        endpoint: endpointLabel,
                        statusCode: nil,
                        attempt: attempt + 1
                    ))
                    try await sleepBeforeRetry(attempt: attempt + 1)
                    continue
                }
                throw error
            } catch {
                lastNetworkError = error
                if attempt < retryPolicy.maxRetries {
                    analyticsRecorder.record(.apiRetry(
                        method: method,
                        endpoint: endpointLabel,
                        statusCode: nil,
                        attempt: attempt + 1
                    ))
                    try await sleepBeforeRetry(attempt: attempt + 1)
                    continue
                }
                throw SiftError.network(error.localizedDescription)
            }

            if response.statusCode == 401, requiresAuth {
                try? tokenStore.deleteToken()
                throw SiftError.unauthorized
            }

            if retryPolicy.shouldRetry(statusCode: response.statusCode, attempt: attempt) {
                analyticsRecorder.record(.apiRetry(
                    method: method,
                    endpoint: endpointLabel,
                    statusCode: response.statusCode,
                    attempt: attempt + 1
                ))
                try await sleepBeforeRetry(attempt: attempt + 1)
                continue
            }

            return try decodeEnvelope(Response.self, from: response)
        }

        if let lastNetworkError {
            throw SiftError.network(lastNetworkError.localizedDescription)
        }

        throw SiftError.network("The request could not be completed.")
    }

    private func sleepBeforeRetry(attempt: Int) async throws {
        let delay = retryPolicy.delayNanoseconds(for: attempt)
        guard delay > 0 else {
            return
        }

        try await Task.sleep(nanoseconds: delay)
    }

    private func analyticsEndpointLabel(for path: String) -> String {
        var components = path.split(separator: "/").map(String.init)
        for index in components.indices where index > 0 {
            if components[index - 1] == "item" || components[index - 1] == "cancellations" {
                components[index] = ":id"
            }
        }
        return components.joined(separator: "/")
    }

    private func decodeEnvelope<Response: Decodable>(
        _ type: Response.Type,
        from response: HTTPDataResponse
    ) throws -> Response {
        let envelope = try decoder.decode(APIEnvelope<Response>.self, from: response.data)

        if let error = envelope.error {
            throw SiftError.api(code: error.code, message: error.message)
        }

        guard (200..<300).contains(response.statusCode) else {
            throw SiftError.network("The server returned status \(response.statusCode).")
        }

        guard let data = envelope.data else {
            throw SiftError.decoding("The server response did not include data.")
        }

        return data
    }
}

enum APIConfiguration {
    static var defaultBaseURL: URL {
        if
            let rawValue = ProcessInfo.processInfo.environment["SIFT_API_BASE_URL"],
            let url = URL(string: rawValue)
        {
            return url
        }

        return URL(string: "http://127.0.0.1:3000/v1")!
    }
}

struct MockSiftAPIClient: SiftAPIClient {
    var bootstrapResponse = AuthBootstrapResponse(token: "mock-jwt")
    var linkTokenResponse = LinkTokenResponse(linkToken: "link-sandbox-mock")
    var exchangeResponse = ExchangePublicTokenResponse(ok: true)
    var accounts: [RemoteAccount] = SeedData.snapshot().accounts.map(RemoteAccount.init(account:))
    var deleteResponse = APIOKResponse(ok: true)
    var syncResponse = TransactionSyncResponse(added: 42, modified: 0, removed: 0, hasMore: false)
    var transactionPages: [[RemoteTransaction]] = []
    var cancellationRequests: [RemoteCancellationRequest] = []
    var createdCancellationStatus: CancellationStatus = .requested

    func bootstrap() async throws -> AuthBootstrapResponse {
        bootstrapResponse
    }

    func createLinkToken() async throws -> LinkTokenResponse {
        linkTokenResponse
    }

    func exchange(publicToken: String) async throws -> ExchangePublicTokenResponse {
        exchangeResponse
    }

    func listAccounts() async throws -> [RemoteAccount] {
        accounts
    }

    func deletePlaidItem(id _: String) async throws -> APIOKResponse {
        deleteResponse
    }

    func deleteUserData() async throws -> APIOKResponse {
        deleteResponse
    }

    func syncTransactions() async throws -> TransactionSyncResponse {
        syncResponse
    }

    func listTransactions(limit: Int, offset: Int) async throws -> [RemoteTransaction] {
        let pageIndex = limit > 0 ? offset / limit : 0
        guard transactionPages.indices.contains(pageIndex) else {
            return []
        }

        return transactionPages[pageIndex]
    }

    func createCancellation(
        subscriptionRef: String,
        merchantName: String,
        method: CancellationMethod
    ) async throws -> RemoteCancellationRequest {
        RemoteCancellationRequest(
            id: "cancel-mock-\(subscriptionRef)-\(method.rawValue)",
            userId: SeedData.defaultUserID,
            subscriptionRef: subscriptionRef,
            merchantName: merchantName,
            method: method,
            status: createdCancellationStatus,
            note: nil,
            createdAt: SeedData.referenceDate,
            updatedAt: SeedData.referenceDate
        )
    }

    func listCancellations() async throws -> [RemoteCancellationRequest] {
        cancellationRequests
    }

    func updateCancellation(
        id: String,
        status: CancellationStatus,
        note: String?
    ) async throws -> RemoteCancellationRequest {
        if let request = cancellationRequests.first(where: { $0.id == id }) {
            return RemoteCancellationRequest(
                id: request.id,
                userId: request.userId,
                subscriptionRef: request.subscriptionRef,
                merchantName: request.merchantName,
                method: request.method,
                status: status,
                note: note ?? request.note,
                createdAt: request.createdAt,
                updatedAt: SeedData.referenceDate
            )
        }

        return RemoteCancellationRequest(
            id: id,
            userId: SeedData.defaultUserID,
            subscriptionRef: SampleRouteID.subscription,
            merchantName: "Subscription",
            method: .guided,
            status: status,
            note: note,
            createdAt: SeedData.referenceDate,
            updatedAt: SeedData.referenceDate
        )
    }
}

private struct EmptyRequestBody: Encodable {}

private struct PublicTokenRequest: Encodable {
    let publicToken: String

    enum CodingKeys: String, CodingKey {
        case publicToken = "public_token"
    }
}

private struct CreateCancellationRequest: Encodable {
    let subscriptionRef: String
    let merchantName: String
    let method: CancellationMethod
}

private struct UpdateCancellationRequest: Encodable {
    let status: CancellationStatus
    let note: String?
}

private struct APIEnvelope<Response: Decodable>: Decodable {
    let data: Response?
    let error: APIErrorPayload?
}

private struct APIErrorPayload: Decodable {
    let code: String
    let message: String
}

private extension NSLock {
    func withLock<Value>(_ body: () throws -> Value) rethrows -> Value {
        lock()
        defer { unlock() }
        return try body()
    }
}
