import SwiftUI

/// 방향 선택 컴포넌트
struct DirectionSelector: View {
    let selectedDirection: RouteDirection
    let onDirectionChange: (RouteDirection) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(RouteDirection.allCases, id: \.self) { direction in
                DirectionButton(
                    direction: direction,
                    isSelected: selectedDirection == direction,
                    action: { onDirectionChange(direction) }
                )
            }
        }
    }
}

/// 방향 선택 버튼
struct DirectionButton: View {
    let direction: RouteDirection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: direction == .jangyuToSasang ? "arrow.right" : "arrow.left")
                    .font(.caption.bold())
                Text(direction.displayName)
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.primary : Color.clear)
            .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(isSelected ? 0 : 0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    DirectionSelector(
        selectedDirection: .jangyuToSasang,
        onDirectionChange: { _ in }
    )
    .padding()
}
