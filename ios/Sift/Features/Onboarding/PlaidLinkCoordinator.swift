import LinkKit
import SwiftUI

enum PlaidLinkResult: Equatable {
    case success(publicToken: String)
    case cancelled
}

enum PlaidLinkOutcome: Equatable {
    case linked
    case cancelled
}

struct BankInstitution: Identifiable, Equatable {
    let id: String
    let name: String
    let monogram: String
    let colorToken: ColorToken

    static let popular: [BankInstitution] = [
        BankInstitution(id: "ins_56", name: "Chase", monogram: "C", colorToken: .clay),
        BankInstitution(id: "ins_10", name: "American Express", monogram: "A", colorToken: .ink),
        BankInstitution(id: "ins_127989", name: "Wells Fargo", monogram: "W", colorToken: .inkSoft),
        BankInstitution(id: "ins_127991", name: "Bank of America", monogram: "B", colorToken: .green),
    ]
}

protocol PlaidLinkPresenting: AnyObject, Sendable {
    @MainActor func link(with linkToken: String, institutionName: String?) async throws -> PlaidLinkResult
}

protocol OnboardingLinkCoordinating: Sendable {
    @MainActor func linkAccount(institution: BankInstitution?) async throws -> PlaidLinkOutcome
}

struct PlaidLinkCoordinator: OnboardingLinkCoordinating {
    private let apiClient: any SiftAPIClient
    private let presenter: any PlaidLinkPresenting

    init(apiClient: any SiftAPIClient, presenter: any PlaidLinkPresenting) {
        self.apiClient = apiClient
        self.presenter = presenter
    }

    @MainActor
    func linkAccount(institution: BankInstitution?) async throws -> PlaidLinkOutcome {
        let token = try await apiClient.createLinkToken().linkToken
        let result = try await presenter.link(with: token, institutionName: institution?.name)

        switch result {
        case let .success(publicToken):
            _ = try await apiClient.exchange(publicToken: publicToken)
            return .linked
        case .cancelled:
            return .cancelled
        }
    }
}

@MainActor
@Observable
final class LinkKitPlaidLinkPresenter: PlaidLinkPresenting {
    var isPresentingLink = false

    private var session: PlaidLinkSession?
    private var continuation: CheckedContinuation<PlaidLinkResult, Error>?

    func link(with linkToken: String, institutionName _: String?) async throws -> PlaidLinkResult {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            do {
                let configuration = LinkTokenConfiguration(
                    token: linkToken,
                    onSuccess: { success in
                        Task { @MainActor in
                            self.finish(with: .success(publicToken: success.publicToken))
                        }
                    },
                    onExit: { exit in
                        Task { @MainActor in
                            if let error = exit.error {
                                self.finish(throwing: SiftError.api(
                                    code: String(describing: error.errorCode),
                                    message: error.localizedDescription
                                ))
                            } else {
                                self.finish(with: .cancelled)
                            }
                        }
                    },
                    onEvent: { _ in },
                    onLoad: {
                        Task { @MainActor in
                            self.isPresentingLink = true
                        }
                    }
                )

                session = try Plaid.createPlaidLinkSession(configuration: configuration)
            } catch {
                finish(throwing: error)
            }
        }
    }

    @ViewBuilder
    func sheet() -> some View {
        if let session {
            session.sheet()
        }
    }

    private func finish(with result: PlaidLinkResult) {
        isPresentingLink = false
        session = nil
        continuation?.resume(returning: result)
        continuation = nil
    }

    private func finish(throwing error: Error) {
        isPresentingLink = false
        session = nil
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

final class MockPlaidLinkPresenter: PlaidLinkPresenting, @unchecked Sendable {
    private let result: PlaidLinkResult

    init(result: PlaidLinkResult = .success(publicToken: "public-sandbox-mock")) {
        self.result = result
    }

    @MainActor
    func link(with _: String, institutionName _: String?) async throws -> PlaidLinkResult {
        result
    }
}
