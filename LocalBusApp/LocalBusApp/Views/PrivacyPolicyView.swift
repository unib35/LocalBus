import SwiftUI
import WebKit

// MARK: - WebView Wrapper

private struct WebViewWrapper: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        // 페이지가 뜨기 전 바탕은 화면 바탕색 (라이트·다크에 따라 바뀐다)
        let background = UIColor(AppTheme.Color.screenBackground)
        webView.backgroundColor = background
        webView.scrollView.backgroundColor = background
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool

        init(isLoading: Binding<Bool>) {
            _isLoading = isLoading
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }
    }
}

// MARK: - 법률 문서 화면

struct PrivacyPolicyView: View {
    @State private var isLoading = true

    private let legalURL = URL(string: "https://unib35.github.io/LocalBus/terms")!

    var body: some View {
        ZStack {
            AppTheme.Color.screenBackground
                .ignoresSafeArea()

            WebViewWrapper(url: legalURL, isLoading: $isLoading)
                .ignoresSafeArea(edges: .bottom)

            if isLoading {
                ProgressView()
                    .tint(AppTheme.Color.secondaryText)
            }
        }
        .navigationTitle("이용약관 및 개인정보")
        .navigationBarTitleDisplayMode(.inline)
        .legacyToolbarBackground(AppTheme.Color.screenBackground.opacity(0.95))
        .toolbar(.hidden, for: .tabBar)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
    .preferredColorScheme(.dark)
}
