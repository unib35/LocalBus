import SwiftUI

// MARK: - Toast

struct ToastMessage: Equatable {
    let icon: String
    let message: String
}

struct ToastView: View {
    let toast: ToastMessage

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.icon)
                .font(.system(size: 14, weight: .semibold))
            Text(toast.message)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(AppTheme.Color.primaryText)
        .padding(.leading, 14)
        .padding(.trailing, 18)
        .frame(height: 44)
        .tintedGlass(
            AppTheme.Color.secondaryButton.opacity(0.9),
            in: Capsule(),
            fallback: AppTheme.Color.secondaryButton
        )
    }
}

extension View {
    func toast(item: Binding<ToastMessage?>) -> some View {
        modifier(ToastModifier(item: item))
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var item: ToastMessage?
    @State private var isVisible = false
    @State private var workItem: DispatchWorkItem?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast = item {
                    ToastView(toast: toast)
                        .padding(.bottom, 16)
                        .opacity(isVisible ? 1 : 0)
                        .offset(y: isVisible ? 0 : 20)
                        .animation(.spring(duration: 0.35), value: isVisible)
                        .transition(.opacity)
                        .zIndex(999)
                }
            }
            .onChange(of: item) { newValue in
                guard newValue != nil else { return }
                workItem?.cancel()
                withAnimation { isVisible = true }
                let task = DispatchWorkItem {
                    withAnimation { isVisible = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        item = nil
                    }
                }
                workItem = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: task)
            }
    }
}
