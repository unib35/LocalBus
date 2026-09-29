import Testing
@testable import JangyuBus

struct PaywallCopyTests {

    @Test func 평소에는_Pro_시작하기() {
        #expect(PaywallCopy.buyButtonTitle(isPurchasing: false, didFail: false, hasProduct: true, isLoadingProducts: false) == "Pro 시작하기")
    }

    @Test func 결제_중에는_결제_확인_중() {
        #expect(PaywallCopy.buyButtonTitle(isPurchasing: true, didFail: false, hasProduct: true, isLoadingProducts: false) == "결제 확인 중")
        #expect(PaywallCopy.buyButtonTitle(isPurchasing: true, didFail: true, hasProduct: true, isLoadingProducts: false) == "결제 확인 중")
    }

    @Test func 실패한_뒤에는_다시_시도() {
        #expect(PaywallCopy.buyButtonTitle(isPurchasing: false, didFail: true, hasProduct: true, isLoadingProducts: false) == "다시 시도")
    }

    @Test func 상품을_못_불러왔으면_불러오기_문구() {
        #expect(PaywallCopy.buyButtonTitle(isPurchasing: false, didFail: false, hasProduct: false, isLoadingProducts: true) == "상품 정보 불러오는 중")
        #expect(PaywallCopy.buyButtonTitle(isPurchasing: false, didFail: true, hasProduct: false, isLoadingProducts: false) == "상품 정보 다시 불러오기")
    }

    @Test func 혜택_첫_줄은_위젯_개수를_밝힌다() {
        #expect(PaywallCopy.benefits.first == "홈 화면 위젯 15종 · 소형·중형·대형")
        #expect(PaywallCopy.benefits.count == 3)
    }
}
