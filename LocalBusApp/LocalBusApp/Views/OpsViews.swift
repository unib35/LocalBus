import SwiftUI
import UIKit

// MARK: - 운영 상황 화면 (디자인 캔버스 C_Operations · OpsUpdate · HomeUnified 배너)
//
// 배너는 노선 헤더 아래 한 줄, 한 번에 하나만. 필수 업데이트만 전체 화면이고 나머지는 저장된 시간표를 계속 보여준다.

/// App Store 링크. 실제 앱 ID로 바꿔야 한다.
enum AppStoreLink {
    // TODO: 실제 App Store ID
    static let url = URL(string: "https://apps.apple.com/app/id0000000000")!
}

// MARK: - 운행 안내 배너

/// 노선 헤더 아래 배너 하나. 두 줄(운휴·변경 예고·오래됨·점검, 최소 높이 60) 또는 한 줄(연결 없음·공휴일, 높이 44).
/// 공휴일·점검은 안내만 하고 눌리지 않는다.
struct OperationsBannerView: View {
    let banner: OperationsBanner
    let onTap: () -> Void

    var body: some View {
        Group {
            if banner.isInteractive {
                Button(action: onTap) { content }
                    .buttonStyle(.plain)
            } else {
                content
            }
        }
        .secondarySurface(cornerRadius: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(banner.isInteractive ? .isButton : [])
    }

    private var content: some View {
        HStack(spacing: 10) {
            icon

            if banner.isCompact {
                Text(banner.title)
                    .font(AppTheme.Typography.caption)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(banner.title)
                        .font(.system(size: 14, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.Color.primaryText)
                    Text(banner.subtitle)
                        .font(AppTheme.Typography.footnote)
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.Color.secondaryText)
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            if banner.actionTitle != nil || banner.showsChevron {
                HStack(spacing: 2) {
                    if let actionTitle = banner.actionTitle {
                        Text(actionTitle)
                            .font(AppTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Color.primaryText)
                            .fixedSize()
                    }
                    if banner.showsChevron {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.Color.secondaryText)
                    }
                }
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, banner.showsChevron ? 8 : (banner.actionTitle != nil ? 12 : 14))
        .padding(.vertical, banner.isCompact ? 0 : 10)
        .frame(minHeight: banner.isCompact ? 44 : 60)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var icon: some View {
        switch banner {
        case .holiday:
            Circle()
                .fill(AppTheme.Color.primaryText)
                .frame(width: 8, height: 8)
        case .offline:
            Image(systemName: banner.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Color.secondaryText)
                .frame(width: 16)
        case .closure, .change, .stale, .maintenance:
            Image(systemName: banner.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(banner.isWarning ? AppTheme.Color.warning : AppTheme.Color.primaryText)
                .frame(width: 18)
        }
    }

    private var accessibilityText: String {
        var parts = [banner.title]
        if !banner.subtitle.isEmpty { parts.append(banner.subtitle) }
        if let actionTitle = banner.actionTitle { parts.append(actionTitle) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - 필수 업데이트 (전체 화면, 닫을 수 없음)

struct RequiredUpdateView: View {
    let currentVersion: String
    let requiredVersion: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("장유사상버스")
                .font(AppTheme.Typography.caption.weight(.bold))
                .foregroundStyle(AppTheme.Color.secondaryText)
                .frame(height: 44)

            Image(systemName: "arrow.down.to.line")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(AppTheme.Color.primaryText)
                .frame(width: 48, height: 48, alignment: .leading)
                .padding(.top, 96)

            Text("업데이트가\n필요해요")
                .font(.system(size: 28, weight: .heavy))
                .tracking(-0.5)
                .lineSpacing(3)
                .foregroundStyle(AppTheme.Color.primaryText)
                .padding(.top, 20)
                .accessibilityAddTraits(.isHeader)

            Text("이 버전에서는 새 시간표를 받을 수 없어요. 업데이트하면 바로 이어서 쓸 수 있어요.")
                .font(AppTheme.Typography.rowValue)
                .lineSpacing(4)
                .foregroundStyle(AppTheme.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            VStack(spacing: 0) {
                infoRow("지금 버전", value: currentVersion)
                RowDivider(leadingInset: 0)
                infoRow("필요한 버전", value: "\(requiredVersion) 이상")
            }
            .background(AppTheme.Color.sheetTile)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.surface, style: .continuous))
            .padding(.top, 28)

            Spacer(minLength: 24)

            Button {
                UIApplication.shared.open(AppStoreLink.url)
            } label: {
                Text("App Store에서 업데이트")
                    .font(.system(size: 17, weight: .bold))
            }
            .buttonStyle(PrimaryButtonStyle(height: 52))

            Text("저장해 둔 알림과 설정은 그대로 남아요")
                .font(AppTheme.Typography.footnote)
                .foregroundStyle(AppTheme.Color.tertiaryText)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(OpsPalette.fullScreenBackground.ignoresSafeArea())
        .interactiveDismissDisabled(true)
    }

    private func infoRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.Typography.rowBody.weight(.medium))
                .foregroundStyle(AppTheme.Color.primaryText)
            Spacer()
            Text(value)
                .font(AppTheme.Typography.rowValue)
                .monospacedDigit()
                .foregroundStyle(AppTheme.Color.secondaryText)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .accessibilityElement(children: .combine)
    }
}

/// 운영 화면 전용 색. 필수 업데이트는 다크에서 런치 스크린과 같은 #111111, 라이트에서는 화면 바탕 #F5F5F5.
enum OpsPalette {
    static let fullScreenBackground = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.067, alpha: 1)   // #111111
            : UIColor(white: 0.96, alpha: 1)    // #F5F5F5
    })
}

private extension View {
    /// 아래쪽 시트의 바탕과 위 모서리 (iOS 16.4 미만은 시스템 기본 모서리)
    @ViewBuilder
    func opsSheetChrome(background: Color, cornerRadius: CGFloat) -> some View {
        if #available(iOS 16.4, *) {
            self
                .presentationBackground(background)
                .presentationCornerRadius(cornerRadius)
        } else {
            self.background(background.ignoresSafeArea())
        }
    }
}

// MARK: - 권장 업데이트 (아래쪽 시트, 닫을 수 있음)

struct RecommendedUpdateSheet: View {
    static let skippedVersionKey = "skippedUpdateVersion"

    let version: String
    let message: String
    let onUpdate: () -> Void
    let onSkipVersion: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("업데이트")
                    .font(AppTheme.Typography.footnote.weight(.bold))
                    .foregroundStyle(AppTheme.Color.screenBackground)
                    .padding(.horizontal, 9)
                    .frame(height: 22)
                    .background(Capsule().fill(AppTheme.Color.primaryText))
                Text("버전 \(version)")
                    .font(AppTheme.Typography.footnote)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }

            Text("새 버전이 나왔어요")
                .font(AppTheme.Typography.sheetTitle)
                .foregroundStyle(AppTheme.Color.primaryText)
                .padding(.top, 12)

            Text(message)
                .font(AppTheme.Typography.rowValue)
                .lineSpacing(4)
                .foregroundStyle(AppTheme.Color.primaryText.opacity(0.83))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            Spacer(minLength: 16)

            Button("App Store에서 업데이트", action: onUpdate)
                .buttonStyle(PrimaryButtonStyle(height: 52))

            // 시트가 하나뿐이므로 공지 다이얼로그와 같은 자리에 겹쳐 뜨지 않는다 — MainView.presentLaunchPrompts 참고
            HStack {
                Button("이 버전은 다시 묻지 않기", action: onSkipVersion)
                    .font(AppTheme.Typography.rowValue.weight(.semibold))
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .frame(height: 48)
                    .padding(.horizontal, 8)
                    .padding(.leading, -8)
                Spacer()
                Button("나중에", action: onLater)
                    .font(AppTheme.Typography.rowValue.weight(.semibold))
                    .foregroundStyle(AppTheme.Color.primaryText)
                    .frame(height: 48)
                    .padding(.horizontal, 8)
                    .padding(.trailing, -8)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .opsSheetChrome(background: AppTheme.Color.sheetTile, cornerRadius: 24)
        .presentationDetents([.height(330)])
        .presentationDragIndicator(.hidden)
    }

    /// 이 버전은 다시 묻지 않기
    static func skip(version: String) {
        UserDefaults.standard.set(version, forKey: skippedVersionKey)
    }

    static func isSkipped(version: String) -> Bool {
        UserDefaults.standard.string(forKey: skippedVersionKey) == version
    }
}

// MARK: - Preview

#Preview("배너") {
    VStack(spacing: 12) {
        OperationsBannerView(banner: .closure(title: "오늘 22:10 이후 버스는 운행하지 않아요", subtitle: "막차 21:40 · 도로 공사"), onTap: {})
        OperationsBannerView(banner: .change(title: "10월 1일부터 시간표가 바뀌어요", noticeID: nil), onTap: {})
        OperationsBannerView(banner: .holiday, onTap: {})
        OperationsBannerView(banner: .stale(baselineText: "3월 8일"), onTap: {})
        OperationsBannerView(banner: .maintenance(message: "새 시간표 확인을 잠시 멈췄어요"), onTap: {})
        OperationsBannerView(banner: .offline(baselineText: "3월 8일"), onTap: {})
    }
    .padding(20)
    .background(AppTheme.Color.screenBackground)
    .preferredColorScheme(.dark)
}

#Preview("필수 업데이트") {
    RequiredUpdateView(currentVersion: "1.0", requiredVersion: "1.2")
        .preferredColorScheme(.dark)
}
