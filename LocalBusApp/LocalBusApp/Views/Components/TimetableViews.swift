import SwiftUI
import UIKit

// MARK: - 시간표 화면 전체 (시간대별 그리드)
//
// 세로 리스트(화면당 6대) 대신 시간대별 그리드로 52회 시간표를 한두 화면에 훑을 수 있게 한다.
// 다음 버스 셀만 강조색. 알림은 셀을 탭해 여는 상세 시트에서 켠다.

struct TimetableScreenView: View {
    @ObservedObject var viewModel: MainViewModel
    var isPreparingShare: Bool = false
    var onShare: (() -> Void)? = nil

    @State private var showNotificationDeniedAlert = false
    @State private var selectedBusInfo: BusDetailInfo?
    @State private var showArriveBy = false
    @State private var notificationToast: ToastMessage?

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(alignment: .leading, spacing: 0) {
                RouteHeaderView(
                    direction: viewModel.selectedDirection,
                    titleFont: .system(size: 28, weight: .heavy),
                    trailing: shareButton,
                    onDirectionChange: { direction in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.changeDirection(to: direction)
                        }
                    }
                )
                .padding(.horizontal, 20)

                scheduleSegment
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                legend
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                grid
                    .padding(.top, 6)
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
        .sheet(isPresented: $showArriveBy) {
            ArriveByView(viewModel: viewModel) { time in
                Task {
                    let status = await NotificationService.shared.authorizationStatus()
                    if status == .denied {
                        showArriveBy = false
                        showNotificationDeniedAlert = true
                    } else {
                        await viewModel.toggleNotification(for: time)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        notificationToast = viewModel.isNotificationScheduled(for: time)
                            ? ToastMessage(icon: "bell.fill", message: "\(time) 버스 알림이 켜졌습니다")
                            : ToastMessage(icon: "bell.slash.fill", message: "\(time) 버스 알림이 꺼졌습니다")
                    }
                }
            }
        }
        .sheet(item: $selectedBusInfo) { info in
            BusDetailView(
                info: info,
                alert: viewModel.alert(for: info.departureTime),
                onSetAlert: { lead, repeats in
                    let status = await NotificationService.shared.authorizationStatus()
                    if status == .denied {
                        selectedBusInfo = nil
                        showNotificationDeniedAlert = true
                        return false
                    }
                    return await viewModel.setAlert(for: info.departureTime, leadMinutes: lead, repeatsWeekdays: repeats)
                },
                onRemoveAlert: {
                    if let alert = viewModel.alert(for: info.departureTime) {
                        viewModel.removeAlert(id: alert.id)
                    }
                }
                ,
                onRefreshTraffic: {
                    await viewModel.refreshTrafficDuration(force: true)
                    return viewModel.arrivalEstimate(for: info.departureTime)
                }
            )
        }
    }

    // MARK: - 헤더 공유 버튼

    private var shareButton: AnyView? {
        AnyView(
            HStack(spacing: 2) {
                Button {
                    showArriveBy = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 13, weight: .semibold))
                        Text("도착 시각으로 찾기")
                            .font(AppTheme.Typography.caption.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.Color.primaryText)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Capsule().fill(AppTheme.Color.surfaceSecondary))
                    .frame(height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if let onShare {
                    Button(action: onShare) {
                        if isPreparingShare {
                            ProgressView()
                                .tint(AppTheme.Color.secondaryText)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(AppTheme.Color.secondaryText)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .buttonStyle(.plain)
                    .disabled(isPreparingShare)
                    .accessibilityLabel("시간표 이미지 공유")
                }
            }
            .padding(.trailing, -12)
        )
    }

    // MARK: - 평일 / 주말 세그먼트

    private var scheduleSegment: some View {
        let today = viewModel.todayScheduleType()
        return PillSegment(
            items: ScheduleType.allCases,
            selected: viewModel.selectedScheduleType,
            label: { type in
                let base = type == .weekday ? "평일" : "주말 · 공휴일"
                return type == today ? "\(base) · 오늘" : base
            },
            onSelect: { type in
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.selectedScheduleType = type
                }
            }
        )
    }

    // MARK: - 범례

    private var legend: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(AppTheme.Color.accent)
                    .frame(width: 10, height: 10)
                Text("다음 버스")
            }

            if !viewModel.currentViaTimes.isEmpty {
                HStack(spacing: 5) {
                    Circle()
                        .fill(AppTheme.Color.secondaryText)
                        .frame(width: 5, height: 5)
                    Text("경유")
                }
            }

            if let start = viewModel.nightFareStartTime {
                HStack(spacing: 3) {
                    Text(start)
                        .foregroundStyle(AppTheme.Color.nightFare)
                        .fontWeight(.bold)
                    Text("부터 심야 요금")
                }
            }

            Spacer(minLength: 0)

            Text("총 \(viewModel.currentTimes.count)회")
                .monospacedDigit()
        }
        .font(AppTheme.Typography.footnote)
        .foregroundStyle(AppTheme.Color.secondaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }

    // MARK: - 시간대별 그리드

    private var hourGroups: [(hour: String, times: [String])] {
        var order: [String] = []
        var groups: [String: [String]] = [:]
        for time in viewModel.currentTimes {
            let hour = String(time.prefix(2))
            if groups[hour] == nil { order.append(hour) }
            groups[hour, default: []].append(time)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }

    private var grid: some View {
        ScrollViewReader { proxy in
            TimelineView(.periodic(from: .now, by: 5)) { context in
                let nextBusTime = viewModel.nextBusTime(at: context.date)

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(hourGroups, id: \.hour) { group in
                            TimetableHourRow(
                                hour: group.hour,
                                times: group.times,
                                nextBusTime: nextBusTime,
                                isVia: { viewModel.isViaBus(for: $0) },
                                isNightFare: { viewModel.isNightFare(for: $0) },
                                isNotificationEnabled: { viewModel.isNotificationScheduled(for: $0) },
                                onTap: { time in
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    selectedBusInfo = viewModel.makeBusDetailInfo(for: time)
                                }
                            )
                            .id(group.hour)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .softScrollEdge()
                .onAppear {
                    scrollToNextBus(nextBusTime, proxy: proxy, delay: 0.1)
                }
                .onChange(of: nextBusTime) { newValue in
                    scrollToNextBus(newValue, proxy: proxy)
                }
                .onChange(of: viewModel.selectedScheduleType) { _ in
                    scrollToNextBus(viewModel.nextBusTime(at: Date()), proxy: proxy, delay: 0.05)
                }
                .onChange(of: viewModel.selectedDirection) { _ in
                    scrollToNextBus(viewModel.nextBusTime(at: Date()), proxy: proxy, delay: 0.05)
                }
            }
        }
    }

    private func scrollToNextBus(_ nextBusTime: String?, proxy: ScrollViewProxy, delay: Double = 0) {
        guard let nextBusTime else { return }
        let hour = String(nextBusTime.prefix(2))
        let action = {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(hour, anchor: .top)
            }
        }
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
        } else {
            action()
        }
    }
}

// MARK: - 시간대 행

struct TimetableHourRow: View {
    let hour: String
    let times: [String]
    let nextBusTime: String?
    let isVia: (String) -> Bool
    let isNightFare: (String) -> Bool
    let isNotificationEnabled: (String) -> Bool
    let onTap: (String) -> Void

    private let columns = [GridItem(.adaptive(minimum: 56, maximum: 56), spacing: 8, alignment: .leading)]

    /// 이 시간대가 모두 지났는지 (다음 버스보다 앞선 시간대)
    private var isPastHour: Bool {
        guard let nextBusTime, let last = times.last else { return false }
        return last < nextBusTime
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(hour)시")
                .font(AppTheme.Typography.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(isPastHour ? AppTheme.Color.tertiaryText : AppTheme.Color.secondaryText)
                .frame(width: 40, height: 40, alignment: .leading)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(times, id: \.self) { time in
                    TimetableCell(
                        time: time,
                        isNext: time == nextBusTime,
                        isPast: nextBusTime.map { time < $0 } ?? false,
                        isVia: isVia(time),
                        isNightFare: isNightFare(time),
                        isNotificationEnabled: isNotificationEnabled(time),
                        onTap: { onTap(time) }
                    )
                }
            }
        }
    }
}

// MARK: - 시간 셀

struct TimetableCell: View {
    let time: String
    let isNext: Bool
    let isPast: Bool
    let isVia: Bool
    let isNightFare: Bool
    let isNotificationEnabled: Bool
    let onTap: () -> Void

    private var minuteText: String { String(time.suffix(2)) }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Text(minuteText)
                    .font(AppTheme.Typography.gridCell.weight(isNext ? .heavy : .semibold))
                    .monospacedDigit()
                    .foregroundStyle(textColor)

                if isNotificationEnabled {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isNext ? AppTheme.Color.accentForeground : AppTheme.Color.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.top, 4)
                        .padding(.trailing, 5)
                }

                if isVia {
                    Circle()
                        .fill(isNext ? AppTheme.Color.accentForeground : AppTheme.Color.secondaryText)
                        .frame(width: 5, height: 5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 5)
                }
            }
            .frame(width: 56, height: 40)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.gridCell, style: .continuous)
                    .fill(backgroundColor)
            )
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.gridCell, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isNext ? [.isSelected] : [])
    }

    private var textColor: Color {
        if isNext { return AppTheme.Color.accentForeground }
        if isPast { return AppTheme.Color.tertiaryText }
        if isNightFare { return AppTheme.Color.nightFare }
        return AppTheme.Color.primaryText
    }

    private var backgroundColor: Color {
        if isNext { return AppTheme.Color.accent }
        if isPast { return Color.clear }
        return AppTheme.Color.surface
    }

    private var accessibilityText: String {
        var parts = ["\(time) 출발"]
        if isNext { parts.append("다음 버스") }
        if isPast { parts.append("지난 버스") }
        if isVia { parts.append("경유") }
        if isNightFare { parts.append("심야 요금") }
        if isNotificationEnabled { parts.append("알림 설정됨") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @StateObject var viewModel = MainViewModel()
        var body: some View {
            TimetableScreenView(viewModel: viewModel, onShare: {})
                .preferredColorScheme(.dark)
        }
    }
    return PreviewWrapper()
}
