import SwiftUI

// MARK: - 광고 자리 (디자인 캔버스 AdsPlan — 도입하게 되면)
//
// 권장 두 곳(홈 목록 아래, 전체 시간표 탭 바 위)과 목록 끝(받은 알림함)에 자리만 잡아 둔다.
// 광고 SDK가 없거나 Pro면 아무것도 그리지 않는다(빈칸을 남기지 않음). 운영 안내 배너가 뜬 날은 홈 광고를 내린다.

enum AdsConfig {
    /// 광고를 도입하기 전까지 false. 켜면 자리 표시(점선 상자)가 보인다.
    static let isEnabled = false
}

enum AdPlacement {
    /// 홈 · 이어지는 버스 목록 아래 (배너 320 × 50)
    case homeBottom
    /// 전체 시간표 · 탭 바 바로 위 고정 (배너 320 × 50)
    case timetableAnchor
    /// 받은 알림함 · 날짜 묶음 아래 (목록 모양)
    case inboxNative
}

struct AdSlotView: View {
    let placement: AdPlacement
    /// Pro는 광고 없음
    var isPro: Bool = false
    /// 운영 안내 배너가 떠 있으면 홈 광고는 내린다
    var isSuppressed: Bool = false
    var onProTap: (() -> Void)? = nil

    private var isVisible: Bool { Self.isVisible(isPro: isPro, isSuppressed: isSuppressed) }

    /// 광고 자리가 실제로 그려지는지. 홈은 광고가 보이면 이어지는 버스를 3대로 줄인다.
    static func isVisible(isPro: Bool, isSuppressed: Bool) -> Bool {
        AdsConfig.isEnabled && !isPro && !isSuppressed
    }

    var body: some View {
        if isVisible {
            switch placement {
            case .homeBottom, .timetableAnchor:
                banner
            case .inboxNative:
                native
            }
        }
    }

    private var adTag: some View {
        Text("광고")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(AppTheme.Color.screenBackground)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(AppTheme.Color.secondaryText))
    }

    private var proLink: some View {
        Button {
            onProTap?()
        } label: {
            HStack(spacing: 2) {
                Text("Pro는 광고 없음")
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
            }
            .font(AppTheme.Typography.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.Color.secondaryText)
            .padding(.horizontal, 8)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var banner: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                adTag
                Text("배너 자리 320 × 50")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }
            Spacer(minLength: 0)
            proLink
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(height: 58)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(AppTheme.Color.tertiaryText.opacity(0.6))
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("광고")
    }

    private var native: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(AppTheme.Color.secondaryButton)
                .frame(width: 36, height: 36)
                .overlay(adTag.scaleEffect(0.85))
            VStack(alignment: .leading, spacing: 3) {
                Text("광고 자리 · 목록 모양")
                    .font(AppTheme.Typography.rowBody)
                    .foregroundStyle(AppTheme.Color.primaryText)
                Text("알림으로 오해하지 않게 점·시각 없이")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }
            Spacer(minLength: 0)
            proLink
                .padding(.top, -8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.surface, style: .continuous)
                .fill(AppTheme.Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.surface, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(AppTheme.Color.tertiaryText.opacity(0.6))
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("광고")
    }
}
