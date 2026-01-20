import SwiftUI

/// 메인 화면
struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var showingInfo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // 오프라인 배너
                    if viewModel.isOffline {
                        OfflineBanner()
                    }

                    // 공지 배너
                    if viewModel.hasNotice {
                        NoticeBanner(message: viewModel.noticeMessage ?? "")
                    }

                    VStack(spacing: 16) {
                        // 방향 선택 (양방향 지원시에만 표시)
                        if viewModel.hasRoutes {
                            DirectionSelector(
                                selectedDirection: viewModel.selectedDirection,
                                onDirectionChange: { direction in
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        viewModel.changeDirection(to: direction)
                                    }
                                }
                            )
                        }

                        // 다음 버스 실시간 카운트다운 카드
                        if viewModel.isLoading {
                            LoadingCard()
                        } else if viewModel.isServiceEnded {
                            EndOfServiceCard(firstBusTime: viewModel.firstBusTime)
                        } else if let nextTime = viewModel.nextBusTime {
                            LiveCountdownCard(
                                nextBusTime: nextTime,
                                countdownText: viewModel.countdownText,
                                direction: viewModel.currentDirectionName,
                                isNotificationScheduled: viewModel.isNotificationScheduled(for: nextTime),
                                onNotificationTap: {
                                    Task {
                                        await viewModel.toggleNotification(for: nextTime)
                                    }
                                }
                            )
                        }

                        // 노선 정보 (소요시간/요금)
                        if viewModel.hasRoutes && viewModel.durationMinutes > 0 {
                            RouteInfoBar(
                                durationMinutes: viewModel.durationMinutes,
                                fareText: viewModel.fareText
                            )
                        }

                        // 정류장 경로
                        if viewModel.hasRoutes && !viewModel.currentStops.isEmpty {
                            RouteStopsView(
                                stops: viewModel.currentStops,
                                durationMinutes: viewModel.durationMinutes
                            )
                        }

                        // 첫차/막차 정보
                        if !viewModel.isLoading && !viewModel.currentTimes.isEmpty {
                            FirstLastBusInfo(
                                firstBus: viewModel.firstBusTime,
                                lastBus: viewModel.lastBusTime
                            )
                        }

                        // 평일/주말 탭
                        ScheduleTypePicker(selection: $viewModel.selectedScheduleType)

                        // 시간표 그리드
                        if !viewModel.isLoading {
                            TimetableGrid(
                                times: viewModel.currentTimes,
                                nextBusTime: viewModel.nextBusTime
                            )
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("시외버스")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showingInfo) {
                InfoView()
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            await viewModel.onAppear()
        }
    }
}

// MARK: - 방향 선택

struct DirectionSelector: View {
    let selectedDirection: RouteDirection
    let onDirectionChange: (RouteDirection) -> Void

    var body: some View {
        HStack(spacing: 12) {
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
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue : Color(.secondarySystemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 다음 버스 히어로 카드

struct NextBusHeroCard: View {
    let time: String
    let remainingText: String
    let direction: String

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "bus.fill")
                    .font(.title2)
                Text("다음 버스")
                    .font(.headline)
                Spacer()
            }
            .foregroundStyle(.white.opacity(0.9))

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(time)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(remainingText)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text(direction)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

// MARK: - 로딩 카드

struct LoadingCard: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("시간표 로딩 중...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - 운행 종료 카드

struct EndOfServiceCard: View {
    let firstBusTime: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 44))
                .foregroundStyle(.indigo)

            Text("오늘 운행이 종료되었습니다")
                .font(.headline)

            Text("내일 첫차는 \(firstBusTime) 입니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - 노선 정보 (소요시간/요금)

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
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 정류장 경로

struct RouteStopsView: View {
    let stops: [BusStop]
    let durationMinutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
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
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 실시간 카운트다운 카드

struct LiveCountdownCard: View {
    let nextBusTime: String
    let countdownText: String
    let direction: String
    let isNotificationScheduled: Bool
    let onNotificationTap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("다음 버스")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(nextBusTime)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("남은 시간")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(countdownText)
                        .font(.system(size: 32, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }

            HStack {
                Text(direction)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()

                Button(action: onNotificationTap) {
                    HStack(spacing: 4) {
                        Image(systemName: isNotificationScheduled ? "bell.fill" : "bell")
                        Text(isNotificationScheduled ? "알림 ON" : "5분 전 알림")
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isNotificationScheduled ? Color.white : Color.white.opacity(0.2))
                    .foregroundStyle(isNotificationScheduled ? .blue : .white)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.blue, Color.indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

// MARK: - 첫차/막차 정보

struct FirstLastBusInfo: View {
    let firstBus: String
    let lastBus: String

    var body: some View {
        HStack(spacing: 16) {
            InfoChip(icon: "sunrise.fill", title: "첫차", time: firstBus, color: .orange)
            InfoChip(icon: "sunset.fill", title: "막차", time: lastBus, color: .purple)
        }
    }
}

struct InfoChip: View {
    let icon: String
    let title: String
    let time: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(time)
                    .font(.subheadline.bold())
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 오프라인 배너

struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text("오프라인 모드")
                .font(.caption.bold())
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.gray)
    }
}

// MARK: - 공지 배너

struct NoticeBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "megaphone.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .lineLimit(2)
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    }
}

// MARK: - 시간표 타입 선택

struct ScheduleTypePicker: View {
    @Binding var selection: ScheduleType

    var body: some View {
        Picker("시간표", selection: $selection) {
            ForEach(ScheduleType.allCases, id: \.self) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
    }
}

// MARK: - 시간표 그리드 (시간대별 그룹)

struct TimetableGrid: View {
    let times: [String]
    let nextBusTime: String?

    /// 시간대별로 그룹화된 시간표
    private var groupedTimes: [(hour: String, times: [String])] {
        let grouped = Dictionary(grouping: times) { time -> String in
            String(time.prefix(2))
        }
        return grouped.sorted { $0.key < $1.key }.map { (hour: $0.key, times: $0.value) }
    }

    var body: some View {
        VStack(spacing: 16) {
            ForEach(groupedTimes, id: \.hour) { group in
                HourSection(
                    hour: group.hour,
                    times: group.times,
                    nextBusTime: nextBusTime,
                    allTimes: times
                )
            }
        }
    }
}

struct HourSection: View {
    let hour: String
    let times: [String]
    let nextBusTime: String?
    let allTimes: [String]

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    /// 이 시간대에 다음 버스가 있는지
    private var hasNextBus: Bool {
        guard let next = nextBusTime else { return false }
        return times.contains(next)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 시간대 헤더
            HStack(spacing: 6) {
                Text("\(hour)시")
                    .font(.subheadline.bold())
                    .foregroundStyle(hasNextBus ? .blue : .secondary)

                if hasNextBus {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }

                Spacer()
            }
            .padding(.horizontal, 4)

            // 시간 그리드
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(times, id: \.self) { time in
                    TimeCell(
                        time: time,
                        isNextBus: time == nextBusTime,
                        isPast: isPastTime(time)
                    )
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func isPastTime(_ time: String) -> Bool {
        guard let nextTime = nextBusTime,
              let nextIndex = allTimes.firstIndex(of: nextTime),
              let timeIndex = allTimes.firstIndex(of: time) else {
            return nextBusTime == nil
        }
        return timeIndex < nextIndex
    }
}

struct TimeCell: View {
    let time: String
    let isNextBus: Bool
    let isPast: Bool

    /// 분만 표시 (예: "00", "20", "40")
    private var minuteOnly: String {
        String(time.suffix(2))
    }

    var body: some View {
        HStack(spacing: 2) {
            Text(":")
                .font(.callout)
                .foregroundStyle(.tertiary)
            Text(minuteOnly)
                .font(.title3.monospacedDigit())
                .fontWeight(isNextBus ? .bold : .medium)
        }
        .foregroundStyle(cellForegroundColor)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(cellBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isNextBus ? Color.blue : Color.clear, lineWidth: 2.5)
        )
        .shadow(color: isNextBus ? .blue.opacity(0.2) : .clear, radius: 4, x: 0, y: 2)
    }

    private var cellForegroundColor: Color {
        if isNextBus {
            return .blue
        } else if isPast {
            return Color(.tertiaryLabel)
        }
        return .primary
    }

    private var cellBackgroundColor: Color {
        if isNextBus {
            return Color.blue.opacity(0.15)
        } else if isPast {
            return Color(.tertiarySystemFill)
        }
        return Color(.systemBackground)
    }
}

// MARK: - Preview

#Preview {
    MainView()
}
