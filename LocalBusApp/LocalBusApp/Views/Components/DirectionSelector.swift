import SwiftUI

/// 노선 선택과 현재 방향, 반대 방향 전환을 제공하는 컴포넌트
struct DirectionSelector: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let selectedDirection: RouteDirection
    let onDirectionChange: (RouteDirection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            segmentRow(
                items: RouteLine.allCases,
                selectedID: selectedDirection.routeLine,
                label: { $0 == .jangyu ? "장유" : "율하" },
                identifier: { AccessibilityID.routeLine($0.rawValue) },
                onTap: { line in
                    if line != selectedDirection.routeLine {
                        onDirectionChange(line.defaultDirection)
                    }
                }
            )

            if let reverse = selectedDirection.routeLine.directions.first(where: { $0 != selectedDirection }) {
                let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
                layout {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("이동 방향")
                            .font(.caption)
                            .foregroundStyle(HomeDashboardTheme.secondaryText)
                            .accessibilityIdentifier(AccessibilityID.Home.header)
                        Button { onDirectionChange(reverse) } label: {
                            Text(selectedDirection.displayName)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(HomeDashboardTheme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(selectedDirection.displayName)
                        .accessibilityHint(reverse.displayName + " 방향으로 변경")
                        .accessibilityIdentifier(AccessibilityID.direction(selectedDirection.rawValue))
                        .accessibilityAddTraits(.isSelected)
                    }

                    Button { onDirectionChange(reverse) } label: {
                        Label("방향 변경", systemImage: "arrow.left.arrow.right")
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 48)
                            .foregroundStyle(HomeDashboardTheme.primaryText)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // 장식은 버튼 바깥에 두고 터치 영역은 레이블 전체로 지정합니다.
                    .background {
                        Capsule()
                            .fill(HomeDashboardTheme.iconBackground)
                            .allowsHitTesting(false)
                    }
                    .accessibilityLabel("방향 변경: " + reverse.displayName)
                    .accessibilityIdentifier(AccessibilityID.direction(reverse.rawValue))
                }
            }
        }
    }

    private func segmentRow<T: Hashable>(
        items: [T],
        selectedID: T,
        label: @escaping (T) -> String,
        identifier: @escaping (T) -> String,
        onTap: @escaping (T) -> Void
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                Button { onTap(item) } label: {
                    Text(label(item))
                        .font(.body.weight(selectedID == item ? .bold : .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(selectedID == item
                                      ? HomeDashboardTheme.segmentSelected
                                      : Color.clear)
                                .shadow(
                                    color: .black.opacity(selectedID == item ? 0.14 : 0),
                                    radius: 2, x: 0, y: 1
                                )
                        )
                        .foregroundStyle(
                            selectedID == item
                                ? HomeDashboardTheme.segmentSelectedText
                                : HomeDashboardTheme.secondaryText
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label(item) + " 노선")
                .accessibilityIdentifier(identifier(item))
                .accessibilityAddTraits(selectedID == item ? [.isSelected] : [])
            }
        }
        .padding(4)
        .segmentTrack(cornerRadius: 13)
    }
}

#Preview("노선 및 방향 변경") {
    struct PreviewSelector: View {
        @State private var direction = RouteDirection.jangyuToSasang
        var body: some View {
            DirectionSelector(selectedDirection: direction, onDirectionChange: { direction = $0 })
                .padding()
        }
    }
    return PreviewSelector()
}
