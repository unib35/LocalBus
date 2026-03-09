import SwiftUI

// MARK: - 시간표 화면 전체

struct TimetableScreenView: View {
    @ObservedObject var viewModel: MainViewModel

    private var nextBusIndex: Int? {
        guard let nextTime = viewModel.nextBusTime else { return nil }
        return viewModel.currentTimes.firstIndex(of: nextTime)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                directionSelector
                scheduleSegmentPicker
                columnHeader

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.currentTimes.enumerated()), id: \.element) { index, time in
                                TimetableRow(
                                    time: time,
                                    destinationName: viewModel.currentArrivalHubName,
                                    isNextBus: time == viewModel.nextBusTime,
                                    isPast: nextBusIndex.map { index < $0 } ?? false,
                                    isNightFare: viewModel.isNightFare(for: time),
                                    isVia: viewModel.isViaBus(for: time),
                                    isNotificationEnabled: viewModel.isNotificationScheduled(for: time),
                                    onNotificationTap: {
                                        Task { await viewModel.toggleNotification(for: time) }
                                    }
                                )
                                .id(time)
                            }
                        }
                    }
                    .onAppear {
                        if let nextTime = viewModel.nextBusTime {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    proxy.scrollTo(nextTime, anchor: .center)
                                }
                            }
                        }
                    }
                    .onChange(of: viewModel.nextBusTime) { newValue in
                        if let time = newValue {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                proxy.scrollTo(time, anchor: .center)
                            }
                        }
                    }
                    .onChange(of: viewModel.selectedScheduleType) { _ in
                        if let nextTime = viewModel.nextBusTime {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(nextTime, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 노선/방향 선택

    private var directionSelector: some View {
        DirectionSelector(
            selectedDirection: viewModel.selectedDirection,
            onDirectionChange: { direction in
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.changeDirection(to: direction)
                }
            }
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - 세그먼트 피커

    private var scheduleSegmentPicker: some View {
        HStack(spacing: 0) {
            ForEach(ScheduleType.allCases, id: \.self) { type in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedScheduleType = type
                    }
                } label: {
                    ZStack {
                        if viewModel.selectedScheduleType == type {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(HomeDashboardTheme.timetablePickerSelected)
                                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
                        }

                        Text(type.displayLabel)
                            .font(HomeDashboardTypography.segmentSelected)
                            .foregroundStyle(
                                viewModel.selectedScheduleType == type
                                    ? .white
                                    : HomeDashboardTheme.timetableMutedText
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(HomeDashboardTheme.timetablePickerBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(HomeDashboardTheme.timetablePickerBorder, lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    // MARK: - 컬럼 헤더

    private var columnHeader: some View {
        HStack {
            Text("출발 시간 / 노선")
                .font(.system(size: 12, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)

            Spacer()

            Text("알림")
                .font(.system(size: 12, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
        }
    }
}

// MARK: - 시간표 행

struct TimetableRow: View {
    let time: String
    let destinationName: String
    let isNextBus: Bool
    let isPast: Bool
    let isNightFare: Bool
    let isVia: Bool
    let isNotificationEnabled: Bool
    let onNotificationTap: () -> Void

    var body: some View {
        ZStack {
            if isNextBus {
                nextBusBackground
            }

            HStack(spacing: 0) {
                // 시간 + 서브 레이블
                VStack(alignment: .center, spacing: 3) {
                    Text(time)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .tracking(-0.6)
                        .foregroundStyle(.white)

                    if isNextBus {
                        Text("NEXT")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(HomeDashboardTheme.timetableNextBadge)
                    } else if isNightFare {
                        Text("심야")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(Color.orange.opacity(0.85))
                    }
                }
                .frame(width: 72, alignment: .leading)

                // 수직 구분선
                Rectangle()
                    .fill(isNextBus ? Color.white.opacity(0.2) : HomeDashboardTheme.timetablePickerBorder)
                    .frame(width: 1, height: 44)
                    .padding(.horizontal, 24)

                // 노선 타입 + 목적지
                VStack(alignment: .leading, spacing: 5) {
                    routeTypeBadge
                    Text(destinationName)
                        .font(HomeDashboardTypography.headerLabel)
                        .foregroundStyle(
                            isNextBus ? Color.white.opacity(0.9) : HomeDashboardTheme.timetableSecondaryText
                        )
                }

                Spacer()

                // 알림 버튼
                Button(action: onNotificationTap) {
                    ZStack {
                        if isNextBus {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 40, height: 40)
                        }

                        Image(systemName: isNotificationEnabled ? "bell.fill" : "bell")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(
                                isNextBus ? .white : HomeDashboardTheme.timetableSecondaryText
                            )
                    }
                    .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .opacity(isPast ? 0.4 : 1.0)
        .overlay(alignment: .top) {
            if !isNextBus {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
            }
        }
    }

    // MARK: - 노선 타입 배지

    @ViewBuilder
    private var routeTypeBadge: some View {
        let label = isVia ? "경유" : "직행"

        if isNextBus {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(red: 15/255, green: 23/255, blue: 42/255))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else if isVia {
            Text("경유")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(HomeDashboardTheme.timetablePickerBackground)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(HomeDashboardTheme.timetablePickerSelected, lineWidth: 1)
                )
        } else {
            Text("직행")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(red: 212/255, green: 212/255, blue: 216/255))
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(HomeDashboardTheme.timetablePickerBorder)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(HomeDashboardTheme.timetablePickerSelected, lineWidth: 1)
                )
        }
    }

    private var nextBusBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(HomeDashboardTheme.iconBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 10)
            .padding(.horizontal, 12)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @StateObject var viewModel = MainViewModel()
        var body: some View {
            TimetableScreenView(viewModel: viewModel)
                .preferredColorScheme(.dark)
        }
    }
    return PreviewWrapper()
}
