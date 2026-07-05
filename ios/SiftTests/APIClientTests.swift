@preconcurrency import Foundation
import Testing
@testable import Sift

struct APIClientTests {
    @Test func bootstrapStoresJwtFromEnvelope() async throws {
        let loader = CapturingHTTPDataLoader(response: jsonResponse(#"{"data":{"token":"jwt-123"}}"#))
        let tokenStore = InMemoryTokenStore()
        let client = DefaultSiftAPIClient(
            baseURL: URL(string: "https://api.example.test/v1")!,
            loader: loader,
            tokenStore: tokenStore
        )

        let response = try await client.bootstrap()

        #expect(response.token == "jwt-123")
        #expect(try tokenStore.readToken() == "jwt-123")
        #expect(loader.requests.first?.url?.absoluteString == "https://api.example.test/v1/auth/bootstrap")
    }

    @Test func linkTokenInjectsJwtHeader() async throws {
        let loader = CapturingHTTPDataLoader(response: jsonResponse(#"{"data":{"link_token":"link-sandbox-123"}}"#))
        let client = DefaultSiftAPIClient(
            baseURL: URL(string: "https://api.example.test/v1")!,
            loader: loader,
            tokenStore: InMemoryTokenStore(token: "jwt-abc")
        )

        let response = try await client.createLinkToken()

        #expect(response.linkToken == "link-sandbox-123")
        #expect(loader.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-abc")
    }

    @Test func exchangeEncodesPublicToken() async throws {
        let loader = CapturingHTTPDataLoader(response: jsonResponse(#"{"data":{"ok":true}}"#))
        let client = DefaultSiftAPIClient(
            baseURL: URL(string: "https://api.example.test/v1")!,
            loader: loader,
            tokenStore: InMemoryTokenStore(token: "jwt-abc")
        )

        let response = try await client.exchange(publicToken: "public-sandbox-token")
        let body = try #require(loader.requests.first?.httpBody)
        let decoded = try JSONSerialization.jsonObject(with: body) as? [String: String]

        #expect(response.ok)
        #expect(decoded?["public_token"] == "public-sandbox-token")
    }

    @Test func errorEnvelopeSurfacesSiftError() async throws {
        let loader = CapturingHTTPDataLoader(response: jsonResponse(
            #"{"error":{"code":"validation_error","message":"No public token."}}"#,
            statusCode: 400
        ))
        let client = DefaultSiftAPIClient(
            baseURL: URL(string: "https://api.example.test/v1")!,
            loader: loader,
            tokenStore: InMemoryTokenStore(token: "jwt-abc")
        )

        do {
            _ = try await client.exchange(publicToken: "")
        } catch let error as SiftError {
            #expect(error == .api(code: "validation_error", message: "No public token."))
            return
        }

        Issue.record("Expected API error")
    }

    @Test func listTransactionsDecodesEnvelopeAndQuery() async throws {
        let loader = CapturingHTTPDataLoader(response: jsonResponse(
            #"""
            {
              "data": [
                {
                  "id": "txn-db-1",
                  "userId": "user-preview",
                  "accountId": "acct-main-checking",
                  "plaidTxnId": "plaid-1",
                  "merchantName": "NETFLIX #4471 LOS GATOS",
                  "amountMinor": 1549,
                  "isoCurrency": "USD",
                  "date": "2026-06-15T00:00:00.000Z",
                  "pending": false,
                  "category": "ENTERTAINMENT"
                }
              ]
            }
            """#
        ))
        let client = DefaultSiftAPIClient(
            baseURL: URL(string: "https://api.example.test/v1")!,
            loader: loader,
            tokenStore: InMemoryTokenStore(token: "jwt-abc")
        )

        let transactions = try await client.listTransactions(limit: 25, offset: 50)

        #expect(loader.requests.first?.url?.absoluteString == "https://api.example.test/v1/transactions?limit=25&offset=50")
        #expect(transactions.count == 1)
        #expect(transactions[0].merchantName == "NETFLIX #4471 LOS GATOS")
        #expect(transactions[0].amountMinor == 1_549)
    }

    @Test func listAccountsDecodesLinkedAccountMetadata() async throws {
        let loader = CapturingHTTPDataLoader(response: jsonResponse(
            #"""
            {
              "data": [
                {
                  "id": "acct-db-1",
                  "plaidItemId": "item-db-1",
                  "institutionName": "Sandbox Bank",
                  "mask": "1234",
                  "name": "Everyday Checking",
                  "type": "depository",
                  "status": "active"
                }
              ]
            }
            """#
        ))
        let client = DefaultSiftAPIClient(
            baseURL: URL(string: "https://api.example.test/v1")!,
            loader: loader,
            tokenStore: InMemoryTokenStore(token: "jwt-abc")
        )

        let accounts = try await client.listAccounts()

        #expect(loader.requests.first?.url?.absoluteString == "https://api.example.test/v1/accounts")
        #expect(accounts.count == 1)
        #expect(accounts[0].plaidItemId == "item-db-1")
        #expect(accounts[0].institutionName == "Sandbox Bank")
    }

    @Test func deletePlaidItemUsesAuthenticatedDeleteEndpoint() async throws {
        let loader = CapturingHTTPDataLoader(response: jsonResponse(#"{"data":{"ok":true}}"#))
        let client = DefaultSiftAPIClient(
            baseURL: URL(string: "https://api.example.test/v1")!,
            loader: loader,
            tokenStore: InMemoryTokenStore(token: "jwt-abc")
        )

        let response = try await client.deletePlaidItem(id: "item-db-1")

        #expect(response.ok)
        #expect(loader.requests.first?.httpMethod == "DELETE")
        #expect(loader.requests.first?.url?.absoluteString == "https://api.example.test/v1/plaid/item/item-db-1")
        #expect(loader.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-abc")
    }

    @Test func deleteUserDataUsesPrivacyEndpoint() async throws {
        let loader = CapturingHTTPDataLoader(response: jsonResponse(#"{"data":{"ok":true}}"#))
        let client = DefaultSiftAPIClient(
            baseURL: URL(string: "https://api.example.test/v1")!,
            loader: loader,
            tokenStore: InMemoryTokenStore(token: "jwt-abc")
        )

        let response = try await client.deleteUserData()

        #expect(response.ok)
        #expect(loader.requests.first?.httpMethod == "DELETE")
        #expect(loader.requests.first?.url?.absoluteString == "https://api.example.test/v1/privacy/data")
    }

    @Test func createCancellationEncodesRequest() async throws {
        let loader = CapturingHTTPDataLoader(response: jsonResponse(
            #"""
            {
              "data": {
                "id": "cancel-server-1",
                "userId": "user-preview",
                "subscriptionRef": "sub-streamline-plus",
                "merchantName": "Streamline+",
                "method": "concierge",
                "status": "requested",
                "note": null,
                "createdAt": "2026-06-29T12:00:00.000Z",
                "updatedAt": "2026-06-29T12:00:00.000Z"
              }
            }
            """#
        ))
        let client = DefaultSiftAPIClient(
            baseURL: URL(string: "https://api.example.test/v1")!,
            loader: loader,
            tokenStore: InMemoryTokenStore(token: "jwt-abc")
        )

        let response = try await client.createCancellation(
            subscriptionRef: "sub-streamline-plus",
            merchantName: "Streamline+",
            method: .concierge
        )
        let body = try #require(loader.requests.first?.httpBody)
        let decoded = try JSONSerialization.jsonObject(with: body) as? [String: String]

        #expect(loader.requests.first?.url?.absoluteString == "https://api.example.test/v1/cancellations")
        #expect(decoded?["subscriptionRef"] == "sub-streamline-plus")
        #expect(decoded?["merchantName"] == "Streamline+")
        #expect(decoded?["method"] == "concierge")
        #expect(response.status == .requested)
    }

    @Test func updateCancellationPatchesStatus() async throws {
        let loader = CapturingHTTPDataLoader(response: jsonResponse(
            #"""
            {
              "data": {
                "id": "cancel-server-1",
                "userId": "user-preview",
                "subscriptionRef": "sub-streamline-plus",
                "merchantName": "Streamline+",
                "method": "guided",
                "status": "cancelledByUser",
                "note": "User confirmed cancellation in the guided flow.",
                "createdAt": "2026-06-29T12:00:00.000Z",
                "updatedAt": "2026-06-29T12:05:00.000Z"
              }
            }
            """#
        ))
        let client = DefaultSiftAPIClient(
            baseURL: URL(string: "https://api.example.test/v1")!,
            loader: loader,
            tokenStore: InMemoryTokenStore(token: "jwt-abc")
        )

        let response = try await client.updateCancellation(
            id: "cancel-server-1",
            status: .cancelledByUser,
            note: "User confirmed cancellation in the guided flow."
        )
        let body = try #require(loader.requests.first?.httpBody)
        let decoded = try JSONSerialization.jsonObject(with: body) as? [String: String]

        #expect(loader.requests.first?.url?.absoluteString == "https://api.example.test/v1/cancellations/cancel-server-1")
        #expect(decoded?["status"] == "cancelledByUser")
        #expect(response.status == .cancelledByUser)
    }

    @Test func transientServerFailureRetriesWithSanitizedAnalyticsEvent() async throws {
        let loader = CapturingHTTPDataLoader(responses: [
            jsonResponse(#"{"error":{"code":"temporarily_unavailable","message":"Try again."}}"#, statusCode: 503),
            jsonResponse(#"{"data":{"link_token":"link-after-retry"}}"#),
        ])
        let analytics = AnalyticsRecorderSpy()
        let client = DefaultSiftAPIClient(
            baseURL: URL(string: "https://api.example.test/v1")!,
            loader: loader,
            tokenStore: InMemoryTokenStore(token: "jwt-abc"),
            retryPolicy: .immediate,
            analyticsRecorder: analytics
        )

        let response = try await client.createLinkToken()

        #expect(response.linkToken == "link-after-retry")
        #expect(loader.requests.count == 2)
        #expect(analytics.events == [
            .apiRetry(method: "POST", endpoint: "plaid/link-token", statusCode: 503, attempt: 1),
        ])
    }

    @Test func unauthorizedResponseClearsStoredToken() async throws {
        let tokenStore = InMemoryTokenStore(token: "expired-jwt")
        let loader = CapturingHTTPDataLoader(response: jsonResponse(
            #"{"error":{"code":"unauthorized","message":"Expired."}}"#,
            statusCode: 401
        ))
        let client = DefaultSiftAPIClient(
            baseURL: URL(string: "https://api.example.test/v1")!,
            loader: loader,
            tokenStore: tokenStore,
            retryPolicy: .disabled
        )

        do {
            _ = try await client.createLinkToken()
        } catch let error as SiftError {
            #expect(error == .unauthorized)
            #expect(try tokenStore.readToken() == nil)
            return
        }

        Issue.record("Expected unauthorized error")
    }

    @Test func openAPIContractCoversClientEndpointsAndFields() throws {
        let openAPI = try String(
            contentsOf: repositoryRoot().appending(path: "backend/openapi.yaml"),
            encoding: .utf8
        )

        for path in [
            "/v1/auth/bootstrap",
            "/v1/plaid/link-token",
            "/v1/plaid/exchange",
            "/v1/plaid/item/{id}",
            "/v1/accounts",
            "/v1/transactions/sync",
            "/v1/transactions",
            "/v1/cancellations",
            "/v1/cancellations/{id}",
            "/v1/privacy/data",
        ] {
            #expect(openAPI.contains(path))
        }

        for field in [
            "link_token",
            "public_token",
            "plaidItemId",
            "institutionName",
            "status",
            "userId",
            "amountMinor",
            "subscriptionRef",
            "cancelledByUser",
            "feature_disabled",
        ] {
            #expect(openAPI.contains(field))
        }
    }
}

private final class CapturingHTTPDataLoader: HTTPDataLoading, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [HTTPDataResponse]
    private(set) var requests: [URLRequest] = []

    init(response: HTTPDataResponse) {
        responses = [response]
    }

    init(responses: [HTTPDataResponse]) {
        self.responses = responses
    }

    func loadData(for request: URLRequest) async throws -> HTTPDataResponse {
        lock.withLock {
            requests.append(request)
        }
        return lock.withLock {
            responses.removeFirst()
        }
    }
}

private final class AnalyticsRecorderSpy: AnalyticsRecording, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var events: [AnalyticsEvent] = []

    func record(_ event: AnalyticsEvent) {
        lock.withLock {
            events.append(event)
        }
    }
}

private func jsonResponse(_ json: String, statusCode: Int = 200) -> HTTPDataResponse {
    HTTPDataResponse(data: Data(json.utf8), statusCode: statusCode)
}

private func repositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private extension NSLock {
    func withLock<Value>(_ body: () throws -> Value) rethrows -> Value {
        lock()
        defer { unlock() }
        return try body()
    }
}
