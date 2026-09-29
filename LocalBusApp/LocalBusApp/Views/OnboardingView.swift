import SwiftUI
import FirebaseMessaging

// MARK: - 온보딩 (첫 실행) — 디자인 캔버스 개선안
//
// 3화면, 화면마다 버튼 하나.
// 1. 주로 타는 노선 선택 (건너뛰면 기본값 유지)
// 2. 알림 프라이밍 — 알림 모양을 먼저 보여주고 '알림 켜기'를 눌렀을 때만 iOS 권한 창
// 3. 고른 노선의 실제 다음 버스 미리보기 + 꼭 알아야 할 3가지

/// 노선 선택 행의 한 줄 설명: "갑을장유병원 출발 · 26분 · 2,500원"
enum OnboardingRouteDescription {
    static func text(areaName: String, stopName: String?, platform: String?, durationMinutes: Int?, fare: Int?) -> String {
        var origin = areaName
        if var stop = stopName, !stop.isEmpty {
            if stop.hasSuffix("정류소") { stop.removeLast(3) }
            origin = stop.contains(areaName) ? stop : "\(areaName) (\(stop))"
        }
        if let platform, !platform.isEmpty {
            origin += " \(platform)"
        }

        var parts = ["\(origin) 출발"]
        if let durationMinutes, durationMinutes > 0 {
            parts.append("\(durationMinutes)분")
        }
        if let fare, fare > 0 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.locale = Locale(identifier: "ko_KR")
            parts.append("\(formatter.string(from: NSNumber(value: fare)) ?? "\(fare)")원")
        }
        return parts.joined(separator: " · ")
    }
}

struct OnboardingView: View {
    @ObservedObject var viewModel: MainViewModel
    let onFinish: () -> Void

    @AppStorage("lastMileAlertEnabled") private var lastMileAlertEnabled = true
    @AppStorage("noticeAlertEnabled") private var noticeAlertEnabled = true

    @State private var step = 1
    @State private var selectedDirection: RouteDirection
    @State private var isRequestingPermission = false

    /// 노선별 기본 소요시간. 뷰모델은 고른 노선 값만 내주므로 저장된 시간표에서 한 번 읽는다.
    private let routeDurations: [String: Int]

    /// 진행 막대·선택 고리·타임라인 선 (다크 #333333 / 라이트 #D4D4D4)
    private static let trackColor = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(white: 0.2, alpha: 1) : UIColor(white: 0.83, alpha: 1)
    })

    init(viewModel: MainViewModel, onFinish: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onFinish = onFinish
        _selectedDirection = State(initialValue: viewModel.selectedDirection)
        let service = TimetableService()
        let routes = (service.loadCachedData() ?? service.loadLocalData())?.routes ?? [:]
        routeDurations = routes.mapValues(\.durationMinutes)
    }

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(alignment: .leading, spacing: 0) {
                topBar

                Group {
                    switch step {
                    case 1: routeStep
                    case 2: notificationStep
                    default: readyStep
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                .id(step)

                Spacer(minLength: 16)

                bottomButtons
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: - 상단 진행 표시

    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(1...3, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? AppTheme.Color.primaryText : Self.trackColor)
                        .frame(width: 20, height: 4)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("3단계 중 \(step)단계")

            Spacer()

            if step < 3 {
                Button("건너뛰기") {
                    finish()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Color.secondaryText)
                .buttonStyle(.plain)
                .frame(minHeight: 44)
            }
        }
        .frame(height: 44)
    }

    // MARK: - 1. 노선 선택

    private var routeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepTitle("어느 노선을\n주로 타세요?", subtitle: "홈에 이 노선의 다음 버스가 바로 떠요. 언제든 홈에서 바꿀 수 있어요.")

            VStack(spacing: 0) {
                ForEach(Array(RouteDirection.allCases.enumerated()), id: \.element) { index, direction in
                    Button {
                        selectedDirection = direction
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(direction.displayName)
                                    .font(.system(size: 17, weight: selectedDirection == direction ? .bold : .semibold))
                                    .foregroundStyle(AppTheme.Color.primaryText)
                                Text(routeDescription(for: direction))
                                    .font(AppTheme.Typography.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(AppTheme.Color.secondaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }

                            Spacer(minLength: 8)

                            selectionMark(isSelected: selectedDirection == direction)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 64)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedDirection == direction ? [.isSelected] : [])

                    if index < RouteDirection.allCases.count - 1 {
                        RowDivider()
                    }
                }
            }
            .surfaceCard()
            .padding(.top, 28)

            Text("평일·주말·공휴일 시간표는 날짜에 맞춰 자동으로 골라요.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Color.tertiaryText)
                .padding(.top, 14)
        }
    }

    private func routeDescription(for direction: RouteDirection) -> String {
        OnboardingRouteDescription.text(
            areaName: direction.departureName,
            stopName: boardingStopName(for: direction),
            platform: viewModel.getPlatformNumber(for: direction),
            durationMinutes: routeDurations[direction.rawValue],
            fare: viewModel.getFare(for: direction)
        )
    }

    /// 실제로 타는 정류장 이름. 시간표가 아직 없으면 nil.
    private func boardingStopName(for direction: RouteDirection) -> String? {
        let stops = viewModel.getStops(for: direction)
        return (stops.first(where: \.isDeparture) ?? stops.first)?.name
    }

    private func selectionMark(isSelected: Bool) -> some View {
        ZStack {
            if isSelected {
                Circle().fill(AppTheme.Color.accent)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(AppTheme.Color.accentForeground)
            } else {
                Circle().strokeBorder(Self.trackColor, lineWidth: 2)
            }
        }
        .frame(width: 24, height: 24)
    }

    // MARK: - 2. 알림

    private var notificationStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepTitle("놓치지 않게\n알려드릴게요", subtitle: "원하는 버스를 고르면 출발 5분 전에 알려요. 막차는 매일 30분 전에.")

            notificationPreview
                .padding(.top, 28)

            VStack(spacing: 0) {
                toggleRow(title: "막차 30분 전 알림", description: "매일 막차 출발 30분 전", isOn: $lastMileAlertEnabled)
                RowDivider()
                toggleRow(title: "공지사항 알림", description: "시간표 변경·임시 운휴", isOn: $noticeAlertEnabled)
            }
            .surfaceCard()
            .padding(.top, 20)

            Text("'알림 켜기'를 누르면 iOS 권한 창이 한 번 뜹니다. 설정에서 언제든 바꿀 수 있어요.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Color.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
        }
    }

    private var notificationPreview: some View {
        let snapshot = viewModel.makeTimingSnapshot(at: Date())
        // 운행 종료 뒤에는 내일 첫차로 미리보기를 만든다.
        let time = snapshot.nextBusTime ?? viewModel.firstBusTime
        let arrival = snapshot.nextBusTime == nil
            ? (DateService.timeByAdding(minutes: viewModel.currentDurationMinutes, to: time) ?? "--:--")
            : snapshot.nextBusArrivalTime
        let boardingName = boardingStopName(for: viewModel.selectedDirection) ?? viewModel.currentTerminalName
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.Color.accent)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppTheme.Color.surfaceSecondary))

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("장유사상버스")
                        .font(.system(size: 15, weight: .bold))
                    Spacer()
                    Text("지금")
                        .font(AppTheme.Typography.footnote)
                        .foregroundStyle(AppTheme.Color.secondaryText)
                }
                Text("\(time) 버스가 5분 뒤 출발해요\n\(boardingName) · \(viewModel.currentArrivalHubName) \(arrival) 도착")
                    .font(.system(size: 15, weight: .medium))
                    .monospacedDigit()
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(AppTheme.Color.primaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("알림 미리보기: \(time) 버스가 5분 뒤 출발해요")
    }

    private func toggleRow(title: String, description: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.Typography.rowTitle)
                    .foregroundStyle(AppTheme.Color.primaryText)
                Text(description)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }
            Spacer(minLength: 8)
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(AppTheme.Color.accent)
        }
        .padding(.horizontal, 16)
        .frame(height: 60)
    }

    // MARK: - 3. 준비 완료

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: 12) {
                stepTitle("준비됐어요", subtitle: "앱을 열면 이렇게 다음 버스가 바로 보여요")
                Spacer(minLength: 0)
                Image("SplashMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 76)
                    .accessibilityHidden(true)
            }

            heroPreview
                .padding(.top, 24)

            Text("알아두면 좋아요")
                .font(AppTheme.Typography.groupTitle)
                .foregroundStyle(AppTheme.Color.primaryText)
                .padding(.top, 24)

            VStack(spacing: 0) {
                tipRow(number: 1, title: "하차벨이 없어요", description: "내릴 정류장 전에 기사님께 말씀해 주세요")
                RowDivider()
                tipRow(number: 2, title: "시각을 누르면 알림을 켤 수 있어요", description: "전체 시간표에서 어떤 버스든 5분 전 알림")
                RowDivider()
                tipRow(number: 3, title: "홈 화면 위젯도 있어요", description: "설정 → Pro에서 켤 수 있어요")
            }
            .surfaceCard()
            .padding(.top, 10)
        }
    }

    private var heroPreview: some View {
        let snapshot = viewModel.makeTimingSnapshot(at: Date())
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(snapshot.isServiceEnded ? "오늘 운행 종료 · \(viewModel.selectedDirection.displayName)" : "다음 버스 · \(viewModel.selectedDirection.displayName)")
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Color.secondaryText)
                Spacer()
                if let next = snapshot.nextBusTime, !snapshot.isServiceEnded {
                    Text("\(next) 출발")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.Color.primaryText)
                }
            }

            if snapshot.isServiceEnded {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(snapshot.firstBusTime)
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .tracking(-2)
                        .foregroundStyle(AppTheme.Color.primaryText)
                    Text("내일 첫차")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.Color.secondaryText)
                }
                .padding(.top, 8)
            } else {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    if snapshot.nextBusMinuteDisplay.isEmpty {
                        Text(snapshot.nextBusCountdownDescription)
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppTheme.Color.accent)
                    } else {
                        Text(snapshot.nextBusMinuteDisplay)
                            .font(.system(size: 64, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .tracking(-2)
                            .foregroundStyle(AppTheme.Color.accent)
                        Text("\(snapshot.nextBusUnitDisplay) 후")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppTheme.Color.primaryText)
                    }
                }
                .padding(.top, 8)

                if let next = snapshot.nextBusTime {
                    journeyLine(
                        departureTime: next,
                        arrivalTime: snapshot.nextBusArrivalTime,
                        durationMinutes: viewModel.currentDurationMinutes
                    )
                    .padding(.top, 14)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: AppTheme.Radius.hero)
        .accessibilityElement(children: .combine)
    }

    /// 라벨 없는 한 줄 띠: 07:20 ●──26분──○ 07:46
    private func journeyLine(departureTime: String, arrivalTime: String, durationMinutes: Int) -> some View {
        HStack(spacing: 10) {
            Text(departureTime)
                .font(.system(size: 15, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.Color.primaryText)

            HStack(spacing: 6) {
                Circle()
                    .fill(AppTheme.Color.primaryText)
                    .frame(width: 6, height: 6)
                Rectangle()
                    .fill(Self.trackColor)
                    .frame(height: 2)
                if durationMinutes > 0 {
                    Text("\(durationMinutes)분")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.Color.secondaryText)
                        .fixedSize()
                }
                Rectangle()
                    .fill(Self.trackColor)
                    .frame(height: 2)
                Circle()
                    .strokeBorder(AppTheme.Color.primaryText, lineWidth: 1.5)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity)

            Text(arrivalTime)
                .font(.system(size: 15, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.Color.primaryText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(departureTime) 출발, \(arrivalTime) 도착 예상, \(durationMinutes)분 소요")
    }

    private func tipRow(number: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.Color.accent)
                .frame(width: 22, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppTheme.Typography.rowTitle)
                    .foregroundStyle(AppTheme.Color.primaryText)
                Text(description)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 공통

    private func stepTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppTheme.Typography.screenTitle)
                .tracking(-0.5)
                .lineSpacing(4)
                .foregroundStyle(AppTheme.Color.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 24)
    }

    @ViewBuilder
    private var bottomButtons: some View {
        switch step {
        case 1:
            Button("다음") {
                viewModel.changeDirection(to: selectedDirection)
                step = 2
            }
            .buttonStyle(PrimaryButtonStyle(height: 52))
        case 2:
            VStack(spacing: 6) {
                Button {
                    enableNotifications()
                } label: {
                    HStack(spacing: 8) {
                        if isRequestingPermission {
                            ProgressView().tint(AppTheme.Color.accentForeground)
                        }
                        Text("알림 켜기")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(height: 52, isBusy: isRequestingPermission))
                .disabled(isRequestingPermission)

                Button("나중에") {
                    step = 3
                }
                .font(AppTheme.Typography.buttonLabel)
                .foregroundStyle(AppTheme.Color.secondaryText)
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
        default:
            Button("시작하기") {
                finish()
            }
            .buttonStyle(PrimaryButtonStyle(height: 52))
        }
    }

    // MARK: - 액션

    private func enableNotifications() {
        isRequestingPermission = true
        Task {
            let granted = await NotificationService.shared.requestAuthorization()
            if granted {
                if lastMileAlertEnabled {
                    await viewModel.scheduleLastBusNotification()
                }
                if noticeAlertEnabled {
                    Messaging.messaging().subscribe(toTopic: "notices") { _ in }
                }
            }
            isRequestingPermission = false
            step = 3
        }
    }

    private func finish() {
        onFinish()
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(viewModel: MainViewModel(), onFinish: {})
        .preferredColorScheme(.dark)
}
