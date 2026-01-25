import SwiftUI

// MARK: - 노선 정보 바

/// 소요시간/요금 정보 바
struct RouteInfoBar: View {
    let durationMinutes: Int
    let fareText: String

    var body: some View {
        HStack(spacing: 20) {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .foregroundStyle(.blue)
                Text("약 \(durationMinutes)분")
                    .font(.subheadline.weight(.medium))
            }

            Divider()
                .frame(height: 16)

            HStack(spacing: 6) {
                Image(systemName: "wonsign.circle")
                    .foregroundStyle(.green)
                Text(fareText)
                    .font(.subheadline.weight(.medium))
            }

            Spacer()
        }
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
                            .fill(stop.isDeparture ? Color.blue : Color.green)
                            .frame(width: 12, height: 12)

                        if index < stops.count - 1 {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 2, height: 30)
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
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview("RouteInfoBar") {
    RouteInfoBar(durationMinutes: 40, fareText: "3,200원")
        .padding()
}
