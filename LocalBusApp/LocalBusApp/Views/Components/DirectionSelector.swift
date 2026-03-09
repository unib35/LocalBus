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
                onTap: { onDirectionChange($0) }
            )
        }
    }

    private func segmentRow<T: Hashable>(
        items: [T],
        selectedID: T,
        label: @escaping (T) -> String,
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
                                .fill(selectedID == item ? Color.white : Color.clear)
                        )
                        .foregroundStyle(
                            selectedID == item ? Color.black : HomeDashboardTheme.secondaryText
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(HomeDashboardTheme.segmentBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(HomeDashboardTheme.border, lineWidth: 1)
                )
        )
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
