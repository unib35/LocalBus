import SwiftUI
import UIKit

// MARK: - 공유용 시간표 카드

struct TimetableShareCard: View {
    let direction: RouteDirection
    let scheduleType: ScheduleType
    let times: [String]
    let nightFareStartTime: String?
    let viaTimes: Set<String>

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            header
            timeGrid
            footer
        }
        .background(AppTheme.Color.cardBackground)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - 헤더

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "bus.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.Color.heroText)

                Text("장유시외버스")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.Color.heroText)

                Spacer()

                scheduleTypeBadge
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 10) {
                Text("운행 시간표")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.Color.heroText.opacity(0.55))

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    directionTitle
                    Spacer(minLength: 12)
                    Text("총 \(times.count)회")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.Color.heroText.opacity(0.7))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(
                colors: [AppTheme.Color.heroStart, AppTheme.Color.heroEnd],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.Color.border)
                .frame(height: 1)
        }
    }

    private var directionTitle: some View {
        HStack(spacing: 8) {
            Text(direction.departureLabel)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(AppTheme.Color.heroText)

            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.Color.heroText.opacity(0.5))

            Text(direction.arrivalLabel)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(AppTheme.Color.heroText)
        }
    }

    private var scheduleTypeBadge: some View {
        Text(scheduleType.displayLabel)
            .font(.system(size: 11, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(AppTheme.Color.heroText)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .stroke(AppTheme.Color.heroText.opacity(0.35), lineWidth: 1)
            )
    }

    // MARK: - 시간 그리드

    /// 열 우선 순서로 재배열된 시간 배열 (nil = 빈 셀)
    private var columnOrderedTimes: [String?] {
        let colCount = 4
        let rowCount = Int(ceil(Double(times.count) / Double(colCount)))
        return (0 ..< rowCount * colCount).map { i in
            let row = i / colCount
            let col = i % colCount
            let index = col * rowCount + row
            return index < times.count ? times[index] : nil
        }
    }

    private var timeGrid: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(columnOrderedTimes.enumerated()), id: \.offset) { index, time in
                let col = index % 4
                if let time {
                    timeCell(time, isLastColumn: col == 3)
                } else {
                    Color.clear
                        .frame(height: 48)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(AppTheme.Color.border).frame(height: 0.5)
                        }
                        .overlay(alignment: .trailing) {
                            if col != 3 {
                                Rectangle().fill(AppTheme.Color.border).frame(width: 0.5)
                            }
                        }
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func timeCell(_ time: String, isLastColumn: Bool) -> some View {
        let isNight = nightFareStartTime.map { time >= $0 } ?? false
        let isVia = viaTimes.contains(time)

        return VStack(spacing: 3) {
            Text(time)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(isNight ? AppTheme.Color.nightFare : AppTheme.Color.primaryText)

            if isNight {
                Text("심야")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(AppTheme.Color.nightFare.opacity(0.85))
            } else if isVia {
                Text("경유")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(AppTheme.Color.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.Color.border)
                .frame(height: 0.5)
        }
        .overlay(alignment: .trailing) {
            if !isLastColumn {
                Rectangle()
                    .fill(AppTheme.Color.border)
                    .frame(width: 0.5)
            }
        }
    }

    // MARK: - 푸터

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppTheme.Color.border)
                .frame(height: 1)

            HStack(spacing: 8) {
                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.Color.secondaryText)

                Text("App Store에서 \"장유시외버스\" 검색")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.Color.secondaryText)

                Spacer()

                Text("장유·사상 시외버스")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.Color.tertiaryText)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
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
    let scale: CGFloat = 3.0
    let cardWidth: CGFloat = 390

    let card = TimetableShareCard(
        direction: direction,
        scheduleType: scheduleType,
        times: times,
        nightFareStartTime: nightFareStartTime,
        viaTimes: viaTimes
    )
    .frame(width: cardWidth)
    .fixedSize(horizontal: false, vertical: true)

    let imageRenderer = ImageRenderer(content: card)
    imageRenderer.scale = scale

    guard let cgImage = imageRenderer.cgImage else { return nil }

    // UIGraphicsImageRenderer의 opaque 설정은 CGImage 포맷을 강제하지 못함
    // CGContext를 직접 생성해 noneSkipLast(알파 없음)로 명시적 재렌더링
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
    guard let context = CGContext(
        data: nil,
        width: cgImage.width,
        height: cgImage.height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ) else { return nil }

    // ImageRenderer.cgImage와 새 CGContext는 동일한 좌표계(하단 원점) — 변환 없이 직접 드로우
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

    guard let opaqueCGImage = context.makeImage() else { return nil }
    return UIImage(cgImage: opaqueCGImage, scale: scale, orientation: .up)
}

// MARK: - Preview

#Preview("공유 카드 (평일)") {
    TimetableShareCard(
        direction: .jangyuToSasang,
        scheduleType: .weekday,
        times: [
            "06:00", "06:20", "06:40", "07:00", "07:20", "07:40",
            "08:00", "08:20", "08:40", "09:00", "09:30", "10:00",
            "10:30", "11:00", "11:30", "12:00", "12:30", "13:00",
            "13:30", "14:00", "14:30", "15:00", "15:30", "16:00",
            "16:30", "17:00", "17:30", "18:00", "18:30", "19:00",
            "19:30", "20:00", "20:30", "21:00", "22:00", "22:30",
            "23:00", "23:30"
        ],
        nightFareStartTime: "22:00",
        viaTimes: ["08:20", "13:00"]
    )
    .frame(width: 390)
    .padding()
    .background(Color.black)
}
