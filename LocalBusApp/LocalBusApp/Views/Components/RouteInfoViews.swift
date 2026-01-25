import SwiftUI

// MARK: - 노선 정보 바

/// 소요시간/요금 정보 바
struct RouteInfoBar: View {
    let durationMinutes: Int
    let fareText: String

    var body: some View {
        HStack(spacing: 24) {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                Text("약 \(durationMinutes)분")
                    .font(.subheadline)
            }

            HStack(spacing: 6) {
                Image(systemName: "wonsign.circle")
                    .foregroundStyle(.secondary)
                Text(fareText)
                    .font(.subheadline)
            }

            Spacer()
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 정류장 경로

/// 정류장 경로 타임라인 뷰
struct RouteStopsView: View {
    let stops: [BusStop]
    let durationMinutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(stops.enumerated()), id: \.offset) { index, stop in
                HStack(spacing: 12) {
                    // 타임라인
                    VStack(spacing: 0) {
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 8, height: 8)

                        if index < stops.count - 1 {
                            Rectangle()
                                .fill(Color.primary.opacity(0.2))
                                .frame(width: 1, height: 28)
                        }
                    }

                    // 정류장 정보
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stop.name)
                            .font(.subheadline.weight(.medium))
                        if let desc = stop.description {
                            Text(desc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // 소요시간 (마지막 정류장)
                    if index == stops.count - 1 {
                        Text("약 \(durationMinutes)분")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview("RouteInfoBar") {
    RouteInfoBar(durationMinutes: 40, fareText: "3,200원")
        .padding()
}
