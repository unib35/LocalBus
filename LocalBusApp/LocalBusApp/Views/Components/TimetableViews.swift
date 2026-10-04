import SwiftUI
import UIKit

// MARK: - 시간표 화면 전체

struct TimetableScreenView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var viewModel: MainViewModel
    @State private var showNotificationDeniedAlert = false
    @State private var selectedBusInfo: BusDetailInfo?
    @State private var notificationToast: ToastMessage?

    private func selectedNextBus(at referenceDate: Date) -> String? {
        viewModel.nextBusTimeForSelectedSchedule(at: referenceDate)
    }

    private func nextBusIndex(at referenceDate: Date) -> Int? {
        guard let nextTime = selectedNextBus(at: referenceDate) else { return nil }
        return viewModel.currentTimes.firstIndex(of: nextTime)
    }

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(spacing: 0) {
                if !dynamicTypeSize.isAccessibilitySize {
                    directionSelector
                    scheduleSegmentPicker
                    columnHeader
                }

                ScrollViewReader { proxy in

                    TimelineView(.periodic(from: .now, by: 5)) { context in
                        let nextBusTime = selectedNextBus(at: context.date)
                        let nextBusIndex = nextBusIndex(at: context.date)

                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                if dynamicTypeSize.isAccessibilitySize {
                                    directionSelector
                                    scheduleSegmentPicker
                                    columnHeader
                                }
                                ForEach(Array(viewModel.currentTimes.enumerated()), id: \.element) { index, time in
                                    TimetableRow(
                                        time: time,
                                        destinationName: viewModel.currentArrivalHubName,
                                        isNextBus: time == nextBusTime,
                                        isPast: nextBusIndex.map { index < $0 } ?? false,
                                        isNightFare: viewModel.isNightFare(for: time),
                                        isVia: viewModel.isViaBus(for: time),
                                        isNotificationEnabled: viewModel.isNotificationScheduled(for: time),
                                        onNotificationTap: {
                                            Task {
                                                let result = await viewModel.toggleNotification(for: time)
                                                if case .denied = result { showNotificationDeniedAlert = true }
                                                else { notificationToast = ToastMessage(icon: "bell", message: result.message) }
                                            }
                                        },
                                        onRowTap: {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            selectedBusInfo = viewModel.makeBusDetailInfo(for: time)
                                        }
                                    )
                                    .id(time)
                                    .accessibilityIdentifier(AccessibilityID.Timetable.row(time))
                                }
                            }
                            .accessibilityIdentifier(AccessibilityID.Timetable.list)
                        }
                        .onAppear {
                            scrollToCurrentBus(using: nextBusTime, proxy: proxy, delay: 0.1, duration: 0.4)
                        }
                        .onChange(of: nextBusTime) { newValue in
                            scrollToCurrentBus(using: newValue, proxy: proxy, duration: 0.4)
                        }
                        .onChange(of: viewModel.selectedScheduleType) { _ in
                            scrollToCurrentBus(
                                using: selectedNextBus(at: Date()),
                                proxy: proxy,
                                delay: 0.05,
                                duration: 0.3
                            )
                        }
                        .onChange(of: viewModel.selectedDirection) { _ in
                            scrollToCurrentBus(
                                using: selectedNextBus(at: Date()),
                                proxy: proxy,
                                delay: 0.05,
                                duration: 0.3
                            )
                        }
                    }
                }
            }
        }
        .alert("알림 권한이 필요합니다", isPresented: $showNotificationDeniedAlert) {
            Button("설정으로 이동") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("버스 출발 알림을 받으려면\n설정 > 장유시외버스 > 알림을 허용해주세요.")
        }
        .toast(item: $notificationToast)
        .sheet(item: $selectedBusInfo) { info in
            BusDetailView(
                info: info,
                onNotificationTap: {
                    await viewModel.toggleNotification(for: info.departureTime)
                }
            )
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
                                .fill(HomeDashboardTheme.segmentSelected)
                                .shadow(color: .black.opacity(0.14), radius: 2, x: 0, y: 1)
                        }

                        Text(type.displayLabel)
                            .font(HomeDashboardTypography.segmentSelected)
                            .foregroundStyle(
                                viewModel.selectedScheduleType == type
                                    ? HomeDashboardTheme.segmentSelectedText
                                    : HomeDashboardTheme.timetableMutedText
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityID.schedule(type.accessibilityKey))
                .accessibilityAddTraits(viewModel.selectedScheduleType == type ? [.isSelected] : [])
            }
        }
        .padding(5)

        .segmentTrack(cornerRadius: 8)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    // MARK: - 컬럼 헤더

    private var columnHeader: some View {
        HStack {
            Text("출발 시간 / 노선")
                .font(.caption.weight(.medium))
                .tracking(0.4)
                .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)

            Spacer()

            Text("알림")
                .font(.caption.weight(.medium))
                .tracking(0.4)
                .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(HomeDashboardTheme.border.opacity(0.6))
                .frame(height: 0.5)
        }
    }

    private func scrollToCurrentBus(
        using nextBusTime: String?,
        proxy: ScrollViewProxy,
        delay: Double = 0,
        duration: Double
    ) {
        guard let nextBusTime else { return }

        let scrollAction = {
            withAnimation(.easeInOut(duration: duration)) {
                proxy.scrollTo(nextBusTime, anchor: .center)
            }
        }

        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: scrollAction)
        } else {
            scrollAction()
        }
    }
}

// MARK: - 시간표 행

struct TimetableRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let time: String
    let destinationName: String
    let isNextBus: Bool
    let isPast: Bool
    let isNightFare: Bool
    let isVia: Bool
    let isNotificationEnabled: Bool
    let onNotificationTap: () -> Void
    var onRowTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            // 좌측 강조 bar (다음 버스에만)
            Rectangle()
                .fill(isNextBus ? HomeDashboardTheme.primaryBlue : Color.clear)
                .frame(width: 3)

            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
            layout {
                // 시간
                Text(time)
                    .font(.title2.monospaced().bold())
                    .tracking(-0.5)
                    .monospacedDigit()
                    .foregroundStyle(
                        isNextBus ? HomeDashboardTheme.primaryBlue : (isPast ? HomeDashboardTheme.secondaryText : HomeDashboardTheme.primaryText)
                    )
                    .fixedSize(horizontal: true, vertical: false)

                // 노선 타입 + 목적지
                VStack(alignment: .leading, spacing: 4) {
                    routeTypeBadge
                    Text(destinationName)
                        .font(.subheadline.weight(.regular))
                        .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
                }

                if !dynamicTypeSize.isAccessibilitySize { Spacer() }

                // 상태 라벨 (다음 / 심야)
                statusBadge

                // 알림 버튼
                Button(action: onNotificationTap) {
                    Image(systemName: isNotificationEnabled ? "bell.fill" : "bell")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(
                            isNotificationEnabled
                                ? HomeDashboardTheme.primaryBlue
                                : HomeDashboardTheme.timetableMutedText
                        )
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(time) \(destinationName)행 " + (isNotificationEnabled ? "알림 켜짐" : "알림 꺼짐"))
                .accessibilityHint(isNotificationEnabled ? "탭하여 알림을 끕니다" : "탭하여 버스 출발 알림을 설정합니다")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 17)
            .padding(.trailing, 8)
            .padding(.vertical, 14)
        }
        .background(isNextBus ? HomeDashboardTheme.primaryBlue.opacity(0.06) : Color.clear)

        .contentShape(Rectangle())
        .onTapGesture { onRowTap?() }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(HomeDashboardTheme.border.opacity(0.5))
                .frame(height: 0.5)
                .padding(.leading, 20)
        }
    }

    // MARK: - 노선 타입 배지

    @ViewBuilder
    private var routeTypeBadge: some View {
        let label = isVia ? "경유" : "직행"
        Text(label)
            .font(.caption.weight(.medium))
            .foregroundStyle(
                isVia
                    ? AppTheme.Color.nightFare
                    : HomeDashboardTheme.timetableSecondaryText
            )
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(
                        isVia
                            ? AppTheme.Color.nightFare.opacity(0.12)
                            : HomeDashboardTheme.chipBackground
                    )
            )
    }

    // MARK: - 상태 배지

    @ViewBuilder
    private var statusBadge: some View {
        if isNextBus {
            Text("다음")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Color.primaryForeground)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .tintedGlass(
                    HomeDashboardTheme.primaryBlue,
                    in: Capsule(),
                    fallback: HomeDashboardTheme.primaryBlue
                )
        } else if isNightFare {
            Text("심야")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Color.nightFare)
        }
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
