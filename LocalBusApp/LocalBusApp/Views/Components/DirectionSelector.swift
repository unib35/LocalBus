import SwiftUI

/// 노선 + 방향 2단계 선택 컴포넌트
struct DirectionSelector: View {
    let selectedDirection: RouteDirection
    let onDirectionChange: (RouteDirection) -> Void

    var body: some View {
        VStack(spacing: 8) {
            // 1단계: 노선 선택 (장유 / 율하)
            segmentRow(
                items: RouteLine.allCases,
                selectedID: selectedDirection.routeLine,
                label: { $0.displayName },
                identifier: { AccessibilityID.routeLine($0.rawValue) },
                onTap: { line in
                    if line != selectedDirection.routeLine {
                        onDirectionChange(line.defaultDirection)
                    }
                }
            )

            // 2단계: 방향 선택
            segmentRow(
                items: selectedDirection.routeLine.directions,
                selectedID: selectedDirection,
                label: { $0.displayName },
                identifier: { AccessibilityID.direction($0.rawValue) },
                onTap: { onDirectionChange($0) }
            )
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
                        .font(HomeDashboardTypography.segmentDefault)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
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
                .accessibilityIdentifier(identifier(item))
                .accessibilityAddTraits(selectedID == item ? [.isSelected] : [])
            }
        }
        .padding(4)
        .segmentTrack(cornerRadius: 10)
    }
}

#Preview {
    DirectionSelector(
        selectedDirection: .jangyuToSasang,
        onDirectionChange: { _ in }
    )
    .padding()
    .preferredColorScheme(.dark)
}
