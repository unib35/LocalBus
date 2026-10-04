import SwiftUI
import WebKit

private enum LegalDocument: String, CaseIterable, Identifiable {
    case terms = "이용약관"
    case privacy = "개인정보 처리방침"
    var id: String { rawValue }
    var url: URL {
        URL(string: "https://unib35.github.io/LocalBus/" + (self == .terms ? "terms" : "privacy-policy.html"))!
    }
}

private struct WebViewWrapper: UIViewRepresentable {
    let url: URL
    let colorScheme: ColorScheme
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        if PreviewRuntime.isRunning {
            webView.loadHTMLString("""
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>:root { color-scheme: light dark; } body { font: 17px -apple-system; padding: 20px; line-height: 1.7; }</style>
                <h2>문서 화면 미리보기</h2><p>이 내용은 레이아웃 확인용 샘플입니다.</p>
                <p>실제 앱에서는 선택한 이용약관 또는 개인정보 처리방침을 불러옵니다.</p>
                """, baseURL: nil)
        } else {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        webView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewWrapper
        init(parent: WebViewWrapper) { self.parent = parent }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.errorMessage = nil
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handle(error)
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handle(error)
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if navigationResponse.isForMainFrame,
               let response = navigationResponse.response as? HTTPURLResponse,
               !(200...299).contains(response.statusCode) {
                parent.isLoading = false
                parent.errorMessage = "문서를 불러오지 못했습니다. 잠시 후 다시 시도해주세요."
                decisionHandler(.cancel)
            } else { decisionHandler(.allow) }
        }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            parent.isLoading = false
            parent.errorMessage = "페이지가 종료되었습니다. 다시 불러와주세요."
        }
        private func handle(_ error: Error) {
            guard (error as NSError).code != NSURLErrorCancelled else { return }
            parent.isLoading = false
            parent.errorMessage = "페이지를 불러오지 못했습니다. 네트워크 연결을 확인해주세요."
        }
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @State private var document = LegalDocument.terms
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var reloadID = UUID()

    var body: some View {
        VStack(spacing: 0) {
            Picker("문서", selection: $document) {
                ForEach(LegalDocument.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()
            ZStack {
                WebViewWrapper(url: document.url, colorScheme: colorScheme,
                               isLoading: $isLoading, errorMessage: $errorMessage)
                    .id(reloadID)
                    .opacity(errorMessage == nil ? 1 : 0)
                if let errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.exclamationmark").font(.largeTitle)
                        Text(errorMessage).multilineTextAlignment(.center)
                        Button("다시 시도", action: reload)
                        Button("브라우저에서 열기") { openURL(document.url) }
                    }
                    .padding(24)
                } else if isLoading {
                    ProgressView("문서를 불러오는 중")
                        .padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .background(AppTheme.Color.screenBackground)
        .navigationTitle("이용약관 및 개인정보")
        .navigationBarTitleDisplayMode(.inline)
        .legacyToolbarBackground(AppTheme.Color.screenBackground.opacity(0.95))
        .toolbar(.hidden, for: .tabBar)
        .onChange(of: document) { _ in reload() }
    }

    private func reload() {
        errorMessage = nil
        isLoading = true
        reloadID = UUID()
    }
}

#Preview("약관 및 개인정보 · 라이트") {
    NavigationStack { PrivacyPolicyView() }.preferredColorScheme(.light)
}

#Preview("약관 및 개인정보 · 다크") {
    NavigationStack { PrivacyPolicyView() }.preferredColorScheme(.dark)
}
