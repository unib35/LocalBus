import Foundation
import StoreKit
import WidgetKit

/// StoreKit 2 기반 인앱결제 관리 서비스
@MainActor
final class StoreService: ObservableObject {

    // MARK: - Product IDs

    static let proProductID = "kr.co.lee.LocalBusApp.pro"
    private static let allProductIDs: Set<String> = [proProductID]

    // MARK: - Published State

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var purchaseInFlight = false

    var isPro: Bool {
        purchasedProductIDs.contains(Self.proProductID)
    }

    var proProduct: Product? {
        products.first { $0.id == Self.proProductID }
    }

    // MARK: - Private

    private let entitlementStore: EntitlementStore
    private var transactionListener: Task<Void, Never>?

    // MARK: - Initialization

    init(entitlementStore: EntitlementStore = .shared) {
        self.entitlementStore = entitlementStore
        self.transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Public API

    /// 상품 목록 로드 (앱 시작 또는 Paywall 진입 시 호출)
    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let fetched = try await Product.products(for: Self.allProductIDs)
            products = fetched.sorted { $0.price < $1.price }
            await refreshPurchasedProducts()
        } catch {
            products = []
        }
    }

    /// 구매 실행
    /// - Returns: 성공적으로 구매 완료된 경우 true
    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        purchaseInFlight = true
        defer { purchaseInFlight = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await applyTransaction(transaction)
            await transaction.finish()
            return true

        case .userCancelled, .pending:
            return false

        @unknown default:
            return false
        }
    }

    /// 구매 복원 (Non-Consumable은 반드시 제공해야 함 — App Review 요구사항)
    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshPurchasedProducts()
    }

    // MARK: - Private Helpers

    /// 현재 유효한 모든 entitlement 검사 후 상태 갱신
    private func refreshPurchasedProducts() async {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                owned.insert(transaction.productID)
            }
        }
        purchasedProductIDs = owned
        persistEntitlement()
    }

    private func applyTransaction(_ transaction: Transaction) async {
        if transaction.revocationDate == nil {
            purchasedProductIDs.insert(transaction.productID)
        } else {
            purchasedProductIDs.remove(transaction.productID)
        }
        persistEntitlement()
    }

    private func persistEntitlement() {
        entitlementStore.setPro(isPro)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 백그라운드 트랜잭션 (가족 공유, 다른 기기 구매 등) 수신
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.applyTransaction(transaction)
                    await transaction.finish()
                } catch {
                    continue
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            throw error
        }
    }
}
