import SwiftUI
import FirebaseMessaging

// MARK: - 색상 모드 설정

enum AppColorScheme: Int, CaseIterable {
    case light = 0
    case dark = 1
    case system = 2

    var label: String {
        switch self {
        case .light: return "라이트 모드"
        case .dark: return "다크 모드"
        case .system: return "시스템 설정"
        }
    }

    /// 세그먼트용 짧은 라벨
    var shortLabel: String {
        switch self {
        case .light: return "라이트"
        case .dark: return "다크"
        case .system: return "시스템"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - 설정 화면 (디자인 캔버스 개선안)
//
// 맨 위 "시간표 데이터" 카드에서 업데이트를 확인하고, 아래로 알림·디스플레이·정보 그룹.
// 카드 테두리 없이 평면 서피스와 구분선만. 섹션 제목은 13px 보조 텍스트.

struct InfoView: View {
    @ObservedObject var viewModel: MainViewModel
    @EnvironmentObject private var storeService: StoreService

    @AppStorage("lastMileAlertEnabled") private var lastMileAlertEnabled = true
    @AppStorage("liveActivityEnabled") private var liveActivityEnabled = true
    @AppStorage("noticeAlertEnabled") private var noticeAlertEnabled = true
    @AppStorage("colorSchemePreference") private var colorSchemeRaw = AppColorScheme.dark.rawValue

    /// 시간표 데이터 카드의 상태
    private enum UpdatePhase: Equatable {
        case idle
        case checking
        case latest
        case updated(from: String, to: String)
        case failed
    }

    @State private var updatePhase: UpdatePhase = .idle
    @State private var toast: ToastMessage?
    @State private var showPaywall = false

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let shareMessage = "장유-사상 시외버스 시간표 앱 장유시외버스를 사용해보세요!"

    private var colorScheme: AppColorScheme {
        AppColorScheme(rawValue: colorSchemeRaw) ?? .dark
    }

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("설정")
                        .font(AppTheme.Typography.screenTitle)
                        .foregroundStyle(AppTheme.Color.primaryText)
                        .frame(height: 44)

                    timetableDataCard
                        .padding(.top, 20)

                    // v1.0 무료 출시: IAP 미적용 상태이므로 Pro 업그레이드 진입점을 숨긴다.
                    // IAP 도입 시 아래 줄의 주석을 해제하면 결제 화면 진입점이 복원된다.
                    // proSection.padding(.top, 24)

                    sectionHeader("알림")
                    notificationGroup

                    sectionHeader("디스플레이")
                    displayGroup

                    sectionHeader("정보")
                    infoGroup

                    footer
                        .padding(.top, 20)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .softScrollEdge()
        }
        .toolbar(.hidden, for: .navigationBar)
        .toast(item: $toast)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(storeService)
        }
    }

    // MARK: - 시간표 데이터 카드

    private var timetableDataCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                updateIcon

                VStack(alignment: .leading, spacing: 3) {
                    Text(updateTitle)
                        .font(AppTheme.Typography.rowTitle)
                        .foregroundStyle(AppTheme.Color.primaryText)
                    Text(updateSubtitle)
                        .font(AppTheme.Typography.caption)
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.Color.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)
            .accessibilityElement(children: .combine)

            RowDivider()

            if case .updated = updatePhase {
                NavigationLink(destination: noticeList) {
                    HStack(spacing: 6) {
                        Text("바뀐 내용 보기")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .font(AppTheme.Typography.buttonLabel)
                    .foregroundStyle(AppTheme.Color.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    runUpdateCheck()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                        Text(updatePhase == .checking ? "확인 중…" : (updatePhase == .failed ? "다시 시도" : "업데이트 확인"))
                    }
                    .font(AppTheme.Typography.buttonLabel)
                    .foregroundStyle(updatePhase == .checking ? AppTheme.Color.tertiaryText : AppTheme.Color.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(updatePhase == .checking)
            }
        }
        .surfaceCard()
    }

    private var updateIcon: some View {
        let (background, foreground): (Color, Color) = {
            switch updatePhase {
            case .latest, .updated:
                return (AppTheme.Color.accent.opacity(0.16), AppTheme.Color.accent)
            case .failed:
                return (AppTheme.Color.nightFare.opacity(0.16), AppTheme.Color.nightFare)
            default:
                return (AppTheme.Color.secondaryButton, AppTheme.Color.primaryText)
            }
        }()

        return ZStack {
            Circle().fill(background)
            switch updatePhase {
            case .checking:
                ProgressView()
                    .tint(foreground)
            case .latest, .updated:
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(foreground)
            case .failed:
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(foreground)
            case .idle:
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(foreground)
            }
        }
        .frame(width: 40, height: 40)
        .accessibilityHidden(true)
    }

    private var baselineDate: String {
        viewModel.updatedAtText.replacingOccurrences(of: "-", with: ".")
    }

    private var updateTitle: String {
        switch updatePhase {
        case .idle: return "시간표 데이터"
        case .checking: return "새 시간표 확인 중…"
        case .latest: return "이미 최신 시간표예요"
        case .updated: return "새 시간표를 적용했어요"
        case .failed: return "업데이트를 확인하지 못했어요"
        }
    }

    private var updateSubtitle: String {
        switch updatePhase {
        case .idle:
            if let checked = viewModel.lastUpdateCheckAt {
                return "기준일 \(baselineDate) · 마지막 확인 \(LastCheckedFormatter.text(for: checked))"
            }
            return "기준일 \(baselineDate)"
        case .checking:
            return "기준일 \(baselineDate)"
        case .latest:
            return "기준일 \(baselineDate) · 방금 확인"
        case .updated(let from, let to):
            return "기준일 \(from.replacingOccurrences(of: "-", with: ".")) → \(to.replacingOccurrences(of: "-", with: "."))"
        case .failed:
            return "저장된 시간표(\(baselineDate))는 계속 쓸 수 있어요"
        }
    }

    private func runUpdateCheck() {
        guard updatePhase != .checking else { return }
        updatePhase = .checking
        Task {
            let result = await viewModel.checkForTimetableUpdate()
            withAnimation(.easeInOut(duration: 0.2)) {
                switch result {
                case .latest: updatePhase = .latest
                case .updated(let from, let to): updatePhase = .updated(from: from, to: to)
                case .failed: updatePhase = .failed
                }
            }
        }
    }

    // MARK: - Pro 업그레이드

    private var proSection: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: storeService.isPro ? "checkmark.seal.fill" : "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(storeService.isPro ? AppTheme.Color.accent : AppTheme.Color.primaryText)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(storeService.isPro ? "장유시외버스 Pro 이용 중" : "장유시외버스 Pro로 업그레이드")
                        .font(AppTheme.Typography.rowTitle)
                        .foregroundStyle(AppTheme.Color.primaryText)
                    Text(storeService.isPro ? "모든 기능을 사용 중입니다" : "위젯 기능과 광고 제거")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Color.secondaryText)
                }

                Spacer()

                if !storeService.isPro {
                    chevron
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .surfaceCard(interactive: true)
    }

    // MARK: - 알림

    private var notificationGroup: some View {
        VStack(spacing: 0) {
            toggleRow(
                title: "막차 30분 전 알림",
                description: "매일 막차 출발 30분 전에 알려드려요",
                isOn: $lastMileAlertEnabled
            )
            .onChange(of: lastMileAlertEnabled) { enabled in
                Task {
                    if enabled {
                        await viewModel.scheduleLastBusNotification()
                    } else {
                        viewModel.cancelLastBusNotification()
                    }
                }
                toast = enabled
                    ? ToastMessage(icon: "bell.fill", message: "막차 알림이 켜졌습니다")
                    : ToastMessage(icon: "bell.slash.fill", message: "막차 알림이 꺼졌습니다")
            }

            RowDivider()

            toggleRow(
                title: "Live Activity",
                description: "출발 20분 전부터 잠금 화면에 카운트다운 표시",
                isOn: $liveActivityEnabled
            )
            .onChange(of: liveActivityEnabled) { enabled in
                toast = enabled
                    ? ToastMessage(icon: "livephoto", message: "Live Activity가 활성화됩니다")
                    : ToastMessage(icon: "livephoto.slash", message: "Live Activity가 비활성화됩니다")
            }

            RowDivider()

            toggleRow(
                title: "공지사항 알림",
                description: "시간표 변경·임시 운휴를 푸시로 받기",
                isOn: $noticeAlertEnabled
            )
            .onChange(of: noticeAlertEnabled) { enabled in
                if enabled {
                    Messaging.messaging().subscribe(toTopic: "notices")
                } else {
                    Messaging.messaging().unsubscribe(fromTopic: "notices")
                }
                toast = enabled
                    ? ToastMessage(icon: "megaphone.fill", message: "공지 알림이 켜졌습니다")
                    : ToastMessage(icon: "megaphone.fill", message: "공지 알림이 꺼졌습니다")
            }
        }
        .surfaceCard()
    }

    private func toggleRow(title: String, description: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppTheme.Typography.rowBody)
                    .foregroundStyle(AppTheme.Color.primaryText)
                Text(description)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(AppTheme.Color.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 디스플레이

    private var displayGroup: some View {
        HStack(spacing: 12) {
            Text("화면 모드")
                .font(AppTheme.Typography.rowBody)
                .foregroundStyle(AppTheme.Color.primaryText)

            Spacer(minLength: 8)

            PillSegment(
                items: AppColorScheme.allCases,
                selected: colorScheme,
                style: .compact,
                label: { $0.shortLabel },
                onSelect: { colorSchemeRaw = $0.rawValue }
            )
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .surfaceCard()
    }

    // MARK: - 정보

    private var infoGroup: some View {
        VStack(spacing: 0) {
            NavigationLink(destination: noticeList) {
                navigationRow("공지사항", badge: viewModel.unreadNoticeCount > 0 ? "\(viewModel.unreadNoticeCount)" : nil)
            }
            .buttonStyle(.plain)

            RowDivider()

            NavigationLink(destination: BusTipsView()) {
                navigationRow("버스 이용 안내")
            }
            .buttonStyle(.plain)

            RowDivider()

            NavigationLink(destination: ReportView()) {
                navigationRow("시간표 제보")
            }
            .buttonStyle(.plain)

            RowDivider()

            NavigationLink(destination: ContactView()) {
                navigationRow("문의하기")
            }
            .buttonStyle(.plain)

            RowDivider()

            ShareLink(item: shareMessage) {
                navigationRow("앱 공유")
            }
            .buttonStyle(.plain)
        }
        .surfaceCard()
    }

    private var noticeList: some View {
        NoticeListView(notices: viewModel.notices) { notice in
            viewModel.markNoticeRead(notice.id)
        }
    }

    // MARK: - 푸터

    private var footer: some View {
        HStack(spacing: 6) {
            Text("v\(appVersion)")
            Text("·")
            NavigationLink(destination: PrivacyPolicyView()) {
                Text("이용약관")
            }
            .buttonStyle(.plain)
            Text("·")
            NavigationLink(destination: PrivacyPolicyView()) {
                Text("개인정보 처리방침")
            }
            .buttonStyle(.plain)
        }
        .font(AppTheme.Typography.footnote)
        .foregroundStyle(AppTheme.Color.tertiaryText)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
    }

    // MARK: - 헬퍼 뷰

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppTheme.Typography.caption.weight(.semibold))
            .foregroundStyle(AppTheme.Color.secondaryText)
            .padding(.horizontal, 4)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }

    private func navigationRow(_ title: String, badge: String? = nil) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(AppTheme.Typography.rowBody)
                .foregroundStyle(AppTheme.Color.primaryText)
            if let badge {
                Text(badge)
                    .font(AppTheme.Typography.footnote.weight(.bold))
                    .foregroundStyle(AppTheme.Color.accentForeground)
                    .padding(.horizontal, 7)
                    .frame(height: 20)
                    .background(Capsule().fill(AppTheme.Color.accent))
                    .accessibilityLabel("읽지 않은 공지 \(badge)개")
            }
            Spacer()
            chevron
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .contentShape(Rectangle())
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppTheme.Color.tertiaryText)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        InfoView(viewModel: MainViewModel())
            .environmentObject(StoreService())
    }
    .preferredColorScheme(.dark)
}
