import SwiftUI

// MARK: - 오프라인 배너

/// 오프라인 상태 알림 배너
struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption)
            Text("오프라인 모드")
                .font(.caption.weight(.medium))
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.Color.listCardBackground)
        .liquidGlass(cornerRadius: 0)
    }
}

// MARK: - 공지 배너

/// 공지사항 표시 배너
struct NoticeBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.subheadline)
            Text(message)
                .font(.subheadline)
                .lineLimit(2)
            Spacer()
        }
        .foregroundStyle(.primary)
        .padding()
        .background(AppTheme.Color.listCardBackground)
        .liquidGlass(cornerRadius: 0)
    }
}

// MARK: - Toast

struct ToastMessage: Equatable {
    let icon: String
    let message: String
}

struct ToastView: View {
    let toast: ToastMessage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.icon)
                .font(.system(size: 14, weight: .medium))
            Text(toast.message)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color(white: 0.15, opacity: 0.95))
        )
        .liquidGlass(in: Capsule())
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
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
            .overlay(alignment: .top) {
                if let toast = item {
                    ToastView(toast: toast)
                        .padding(.top, 16)
                        .opacity(isVisible ? 1 : 0)
                        .offset(y: isVisible ? 0 : -20)
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

// MARK: - Preview

#Preview("OfflineBanner") {
    OfflineBanner()
}

#Preview("NoticeBanner") {
    NoticeBanner(message: "설 연휴 특별 운행 안내")
}
