import SwiftUI
import UIKit

// MARK: - 공유용 시간표 카드

struct TimetableShareCard: View {
    let direction: RouteDirection
    let scheduleType: ScheduleType
    let times: [String]
    let nightFareStartTime: String?
    let viaTimes: Set<String>

    private let cardBackground = Color(red: 2/255, green: 6/255, blue: 15/255)
    private let surfaceColor = Color(red: 11/255, green: 15/255, blue: 24/255)
    private let borderColor = Color(red: 31/255, green: 41/255, blue: 55/255)
    private let accentBlue = Color(red: 59/255, green: 130/255, blue: 246/255)
    private let mutedText = Color(red: 107/255, green: 114/255, blue: 128/255)
    private let secondaryText = Color(red: 156/255, green: 163/255, blue: 175/255)

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            header
            timeGrid
            footer
        }
        .background(cardBackground)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - 헤더

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "bus.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(accentBlue)

                Text("LocalBus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                scheduleTypeBadge
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Rectangle()
                .fill(borderColor)
                .frame(height: 1)

            directionInfo
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            Rectangle()
                .fill(borderColor)
                .frame(height: 1)
        }
    }

    private var scheduleTypeBadge: some View {
        Text(scheduleType.displayLabel)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(accentBlue)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(accentBlue.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(accentBlue.opacity(0.3), lineWidth: 1)
            )
    }

    private var directionInfo: some View {
        HStack(spacing: 8) {
            Text(direction.departureLabel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(mutedText)

            Text(direction.arrivalLabel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            Text("총 \(times.count)회 운행")
                .font(.system(size: 12))
                .foregroundStyle(mutedText)
        }
    }

    // MARK: - 시간 그리드

    private var timeGrid: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(times.enumerated()), id: \.offset) { _, time in
                timeCell(time)
            }
        }
        .padding(.vertical, 12)
    }

    private func timeCell(_ time: String) -> some View {
        let isNight = nightFareStartTime.map { time >= $0 } ?? false
        let isVia = viaTimes.contains(time)

        return VStack(spacing: 3) {
            Text(time)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(isNight ? Color.orange.opacity(0.9) : .white)

            if isNight {
                Text("심야")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.orange.opacity(0.7))
            } else if isVia {
                Text("경유")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(borderColor)
                .frame(height: 0.5)
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(borderColor)
                .frame(width: 0.5)
        }
    }

    // MARK: - 푸터

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(borderColor)
                .frame(height: 1)

            HStack(spacing: 6) {
                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(mutedText)

                Text("App Store에서 \"LocalBus\" 검색")
                    .font(.system(size: 12))
                    .foregroundStyle(mutedText)

                Spacer()

                Text("장유·사상 시외버스")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 55/255, green: 65/255, blue: 81/255))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - RouteDirection 레이블 확장

private extension RouteDirection {
    var departureLabel: String {
        switch self {
        case .jangyuToSasang: return "장유 터미널"
        case .sasangToJangyu: return "사상 터미널"
        case .yulhaToSasang:  return "율하 (김해외고)"
        case .sasangToYulha:  return "사상 터미널"
        }
    }

    var arrivalLabel: String {
        switch self {
        case .jangyuToSasang: return "사상 터미널"
        case .sasangToJangyu: return "장유 터미널"
        case .yulhaToSasang:  return "사상 터미널"
        case .sasangToYulha:  return "율하 (김해외고)"
        }
    }
}

// MARK: - 공유 시트

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 이미지 렌더링 헬퍼

@MainActor
func renderTimetableShareImage(
    direction: RouteDirection,
    scheduleType: ScheduleType,
    times: [String],
    nightFareStartTime: String?,
    viaTimes: Set<String>
) -> UIImage? {
    let card = TimetableShareCard(
        direction: direction,
        scheduleType: scheduleType,
        times: times,
        nightFareStartTime: nightFareStartTime,
        viaTimes: viaTimes
    )
    .frame(width: 390)

    let renderer = ImageRenderer(content: card)
    renderer.scale = 3.0
    return renderer.uiImage
}
