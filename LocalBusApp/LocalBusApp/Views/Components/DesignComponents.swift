import SwiftUI
import UIKit

// MARK: - 공통 컴포넌트 (디자인 캔버스 개선안)
//
// 원칙
// - 테두리·그라데이션·그림자 없는 평면 서피스. iOS 26+는 글래스, 이하는 AppTheme.Color.surface.
// - 강조색(AppTheme.Color.accent)은 "지금 탈 버스" 신호와 기본 행동 버튼에만 쓴다.
// - 모든 터치 타깃은 44pt 이상.

// MARK: - Surface

extension View {
    /// 테두리 없는 평면 서피스.
    func surfaceCard(
        cornerRadius: CGFloat = AppTheme.Radius.surface,
        interactive: Bool = false
    ) -> some View {
        glassCard(cornerRadius: cornerRadius, fallback: AppTheme.Color.surface, interactive: interactive)
    }

    /// 서피스 안에서 한 단계 올라온 요소 (칩, 인라인 카드).
    func secondarySurface(cornerRadius: CGFloat = AppTheme.Radius.card) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppTheme.Color.surfaceSecondary)
        )
    }
}

/// 서피스 안 행 사이 구분선.
struct RowDivider: View {
    var leadingInset: CGFloat = 16

    var body: some View {
        Rectangle()
            .fill(AppTheme.Color.divider)
            .frame(height: 1)
            .padding(.leading, leadingInset)
    }
}

// MARK: - Buttons

/// 기본 행동 버튼 — 강조색 배경. 화면마다 하나.
///
/// 쓸 수 없을 때는 중립 배경으로 바뀐다. 진행 중처럼 눌리지는 않지만 강조색을 유지해야 하면 `isBusy`를 켠다.
struct PrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 50
    var isBusy: Bool = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let isUnavailable = !isEnabled && !isBusy
        configuration.label
            .font(AppTheme.Typography.buttonLabelStrong)
            .foregroundStyle(isUnavailable ? AppTheme.Color.tertiaryText : AppTheme.Color.accentForeground)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.primaryButton, style: .continuous)
                    .fill(background(isPressed: configuration.isPressed, isUnavailable: isUnavailable))
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func background(isPressed: Bool, isUnavailable: Bool) -> Color {
        if isUnavailable { return AppTheme.Color.secondaryButton }
        return isPressed ? AppTheme.Color.accentPressed : AppTheme.Color.accent
    }
}

/// 보조 행동 버튼 — 중립 배경.
struct SecondaryButtonStyle: ButtonStyle {
    var height: CGFloat = 46

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.buttonLabel)
            .foregroundStyle(AppTheme.Color.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.secondaryButton, style: .continuous)
                    .fill(AppTheme.Color.secondaryButton)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 44pt 원형 아이콘 버튼 (방향 스왑, 현재 위치 등).
struct CircleIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(AppTheme.Color.primaryText)
            .frame(width: 44, height: 44)
            .background(Circle().fill(AppTheme.Color.surfaceSecondary))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primaryAction: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondaryAction: SecondaryButtonStyle { SecondaryButtonStyle() }
}

extension ButtonStyle where Self == CircleIconButtonStyle {
    static var circleIcon: CircleIconButtonStyle { CircleIconButtonStyle() }
}

// MARK: - PillSegment

/// 흰 알약이 선택을 표시하는 세그먼트. 라벨은 잘리지 않도록 짧게 유지한다.
struct PillSegment<Item: Hashable>: View {
    enum Style {
        /// 화면 폭을 채우는 40pt 세그먼트 (시간표 평일/주말)
        case regular
        /// 행 오른쪽에 붙는 36pt 세그먼트 (설정 화면 모드)
        case compact
    }

    let items: [Item]
    let selected: Item
    var style: Style = .regular
    let label: (Item) -> String
    let onSelect: (Item) -> Void

    private var isCompact: Bool { style == .compact }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                let isSelected = item == selected
                Button {
                    guard !isSelected else { return }
                    onSelect(item)
                } label: {
                    Text(label(item))
                        .font(.system(size: isCompact ? 13 : 14, weight: isSelected ? .bold : .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .foregroundStyle(isSelected ? AppTheme.Color.screenBackground : AppTheme.Color.secondaryText)
                        .padding(.horizontal, isCompact ? 12 : 0)
                        .frame(maxWidth: isCompact ? nil : .infinity)
                        .frame(height: isCompact ? 30 : 34)
                        .background(
                            RoundedRectangle(cornerRadius: isCompact ? 8 : 9, style: .continuous)
                                .fill(isSelected ? AppTheme.Color.primaryText : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(3)
        .frame(height: isCompact ? 36 : 40)
        .background(
            RoundedRectangle(cornerRadius: isCompact ? 10 : 12, style: .continuous)
                .fill(isCompact ? AppTheme.Color.secondaryButton : AppTheme.Color.surface)
        )
    }
}

// MARK: - FlowLayout

/// 칩처럼 폭이 제각각인 항목을 줄바꿈하며 배치한다.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        return arrange(subviews: subviews, width: width).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(subviews: subviews, width: bounds.width)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(subviews: Subviews, width: CGFloat) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowHeight), origins)
    }
}

// MARK: - Chip

/// 선택 가능한 칩 (문의 유형, 노선 선택 등). 높이 40, 캡슐.
struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    var height: CGFloat = 40
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: height < 40 ? 13 : 14, weight: isSelected ? .bold : .semibold))
                .foregroundStyle(isSelected ? AppTheme.Color.screenBackground : AppTheme.Color.primaryText)
                .padding(.horizontal, height < 40 ? 14 : 16)
                .frame(height: height)
                .background(
                    Capsule().fill(isSelected ? AppTheme.Color.primaryText : AppTheme.Color.secondaryButton)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// 정보 라벨 칩 (탑승홈, 직행/경유 등). 눌리지 않는다.
struct LabelChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppTheme.Typography.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.Color.primaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.Color.secondaryButton)
            )
    }
}

// MARK: - RouteHeaderView

/// 노선 헤더: 노선 칩 + 컨텍스트 라벨 / 큰 제목 "장유 → 사상" + 방향 스왑 / 한 줄 요약.
/// 홈·전체 시간표·지도에서 2단 세그먼트를 대체한다.
struct RouteHeaderView: View {
    let direction: RouteDirection
    var contextText: String? = nil
    var subtitle: String? = nil
    var titleFont: Font = AppTheme.Typography.screenTitle
    /// 첫 줄 오른쪽에 컨텍스트 텍스트 대신 놓을 요소 (공유 버튼 등).
    var trailing: AnyView? = nil
    /// 컨텍스트 텍스트 오른쪽에 덧붙이는 44px 아이콘 (홈의 알림 종 등).
    var trailingAccessory: AnyView? = nil
    let onDirectionChange: (RouteDirection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                RouteLineMenu(selectedLine: direction.routeLine) { line in
                    onDirectionChange(line.defaultDirection)
                }

                Spacer(minLength: 8)

                if let trailing {
                    trailing
                } else if let contextText {
                    HStack(spacing: 2) {
                        Text(contextText)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Color.secondaryText)
                            .lineLimit(1)
                        if let trailingAccessory {
                            trailingAccessory
                                .padding(.trailing, -12)
                        }
                    }
                }
            }
            .frame(minHeight: 44)

            HStack(alignment: .center, spacing: 10) {
                Text(direction.departureName)
                    .font(titleFont)
                    .foregroundStyle(AppTheme.Color.primaryText)

                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.Color.tertiaryText)

                Text(direction.arrivalName)
                    .font(titleFont)
                    .foregroundStyle(AppTheme.Color.primaryText)

                Spacer(minLength: 8)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onDirectionChange(direction.opposite)
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .buttonStyle(.circleIcon)
                .accessibilityLabel("방향 바꾸기")
                .accessibilityHint("\(direction.opposite.displayName)으로 바꿉니다")
            }
            .padding(.top, 14)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(direction.displayName)

            if let subtitle {
                Text(subtitle)
                    .font(AppTheme.Typography.screenSubtitle)
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .lineLimit(1)
                    .padding(.top, 4)
            }
        }
    }
}

/// "장유 노선 ▾" 칩. 탭하면 노선(장유/율하)을 고르는 메뉴가 뜬다.
struct RouteLineMenu: View {
    let selectedLine: RouteLine
    let onSelect: (RouteLine) -> Void

    var body: some View {
        Menu {
            ForEach(RouteLine.allCases, id: \.self) { line in
                Button {
                    onSelect(line)
                } label: {
                    if line == selectedLine {
                        Label(line.displayName, systemImage: "checkmark")
                    } else {
                        Text(line.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedLine.displayName)
                    .font(AppTheme.Typography.caption.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(AppTheme.Color.primaryText)
            .padding(.leading, 12)
            .padding(.trailing, 10)
            .frame(height: 32)
            .background(Capsule().fill(AppTheme.Color.surfaceSecondary))
            .contentShape(Capsule())
        }
        .accessibilityLabel("노선 선택: \(selectedLine.displayName)")
    }
}

// MARK: - JourneyStrip

/// 출발 ●──26분──○ 도착 한 줄. 히어로와 상세 시트에서 같이 쓴다.
struct JourneyStripView: View {
    let departureTime: String
    let arrivalTime: String
    let destinationName: String
    let durationMinutes: Int

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("출발")
                    .font(AppTheme.Typography.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Color.secondaryText)
                Text(departureTime)
                    .font(AppTheme.Typography.rowTime.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.primaryText)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(AppTheme.Color.primaryText)
                    .frame(width: 6, height: 6)
                Rectangle()
                    .fill(AppTheme.Color.divider)
                    .frame(height: 2)
                if durationMinutes > 0 {
                    Text("\(durationMinutes)분")
                        .font(AppTheme.Typography.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Color.secondaryText)
                }
                Rectangle()
                    .fill(AppTheme.Color.divider)
                    .frame(height: 2)
                Circle()
                    .stroke(AppTheme.Color.primaryText, lineWidth: 1.5)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(destinationName) 도착 예상")
                    .font(AppTheme.Typography.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Color.secondaryText)
                Text(arrivalTime)
                    .font(AppTheme.Typography.rowTime.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.primaryText)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(departureTime) 출발, \(destinationName) \(arrivalTime) 도착 예상, \(durationMinutes)분 소요")
    }
}

// MARK: - InlineBanner

/// 한 줄 상태 배너 (오프라인, 공지). 아이콘 + 문구 + 선택적 텍스트 버튼.
struct InlineBanner: View {
    let systemImage: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Color.secondaryText)

            Text(message)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Color.primaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Color.primaryText)
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 44)
        .secondarySurface(cornerRadius: 12)
    }
}

// MARK: - Preview

#Preview("RouteHeaderView") {
    VStack(alignment: .leading, spacing: 24) {
        RouteHeaderView(
            direction: .jangyuToSasang,
            contextText: "9월 22일 화 · 평일 시간표",
            subtitle: "장유 터미널 출발 · 26분 소요 · 2,500원",
            onDirectionChange: { _ in }
        )

        PillSegment(
            items: ScheduleType.allCases,
            selected: .weekday,
            label: { $0.displayLabel },
            onSelect: { _ in }
        )

        Button("5분 전 알림 받기") {}
            .buttonStyle(.primaryAction)

        Button("정류장 6곳") {}
            .buttonStyle(.secondaryAction)

        InlineBanner(
            systemImage: "wifi.slash",
            message: "연결 없음 · 3월 8일 기준 저장된 시간표를 보여드려요",
            actionTitle: "다시 시도",
            action: {}
        )
    }
    .padding(20)
    .background(AppTheme.Color.screenBackground)
    .preferredColorScheme(.dark)
}
