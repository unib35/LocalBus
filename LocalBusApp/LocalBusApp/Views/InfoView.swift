import SwiftUI

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

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - 설정 화면

struct InfoView: View {
    @AppStorage("lastMileAlertEnabled") private var lastMileAlertEnabled = true
    @AppStorage("delayAlertEnabled") private var delayAlertEnabled = false
    @AppStorage("colorSchemePreference") private var colorSchemeRaw = AppColorScheme.dark.rawValue

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    private var colorScheme: AppColorScheme {
        AppColorScheme(rawValue: colorSchemeRaw) ?? .dark
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    notificationSection
                    displaySection
                    infoSection

                    Text("Bus Schedule App © 2024")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 99/255, green: 99/255, blue: 102/255))
                        .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black.opacity(0.95), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - 알림 설정

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("알림 설정")

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    iconBox(systemName: "bell.fill")
                    Text("막차 30분 전 알림")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                    Spacer()
                    Toggle("", isOn: $lastMileAlertEnabled)
                        .labelsHidden()
                        .tint(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                rowDivider

                HStack(spacing: 12) {
                    iconBox(systemName: "clock.badge.exclamationmark")
                    Text("지연 정보 실시간 알림")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                    Spacer()
                    Toggle("", isOn: $delayAlertEnabled)
                        .labelsHidden()
                        .tint(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .settingsCard()

            Text("운행 상황에 따라 알림이 지연될 수 있습니다.")
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 142/255, green: 142/255, blue: 147/255))
                .padding(.horizontal, 12)
        }
    }

    // MARK: - 디스플레이

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("디스플레이")

            VStack(spacing: 0) {
                ForEach(Array(AppColorScheme.allCases.enumerated()), id: \.element.rawValue) { index, scheme in
                    Button {
                        colorSchemeRaw = scheme.rawValue
                    } label: {
                        HStack {
                            Text(scheme.label)
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                            Spacer()
                            if colorScheme == scheme {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)

                    if index < AppColorScheme.allCases.count - 1 {
                        rowDivider
                    }
                }
            }
            .settingsCard()
        }
    }

    // MARK: - 정보

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("정보")

            VStack(spacing: 0) {
                // 버전 정보
                HStack {
                    Text("버전 정보")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("v\(appVersion)")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(red: 142/255, green: 142/255, blue: 147/255))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                rowDivider

                // 공지사항
                NavigationLink(destination: NoticeListView(notices: sampleNotices)) {
                    infoNavigationRow("공지사항")
                }
                .buttonStyle(.plain)

                rowDivider

                // 시간표 제보
                NavigationLink(destination: ReportView()) {
                    infoNavigationRow("시간표 제보")
                }
                .buttonStyle(.plain)

                rowDivider

                // 문의하기
                NavigationLink(destination: ContactView()) {
                    infoNavigationRow("문의하기")
                }
                .buttonStyle(.plain)

                rowDivider

                // 이용약관 및 개인정보처리방침
                NavigationLink(destination: PrivacyPolicyView()) {
                    infoNavigationRow("이용약관 및 개인정보처리방침")
                }
                .buttonStyle(.plain)
            }
            .settingsCard()
        }
    }

    // MARK: - 공지사항 데이터

    private var sampleNotices: [NoticeItem] {
        [
            NoticeItem(
                id: "notice-001",
                title: "2025년 8월 25일부\n운행 시간표 변경 안내",
                date: "2025.08.14",
                author: "관리자",
                isNew: true,
                body: [
                    "안녕하세요. 장유-사상 시외버스 운행 시간표가 2025년 8월 25일부로 일부 변경됩니다.",
                    "이번 변경은 최근 출퇴근 시간대의 교통 혼잡도 증가와 이용객 수요 변화를 반영하여 더 효율적인 배차 간격을 제공하기 위함입니다. 이용에 착오 없으시길 바랍니다.",
                    "자세한 변경 시간표는 아래를 참고해 주시기 바랍니다."
                ],
                timetableSummary: NoticeTimetableSummary(
                    effectiveDate: "2025.08.25",
                    departureLabel: "장유 출발",
                    arrivalLabel: "사상 도착",
                    rows: [
                        NoticeTimetableRow(departure: "06:20", arrival: "06:46", isNew: false),
                        NoticeTimetableRow(departure: "06:40", arrival: "07:06", isNew: true),
                        NoticeTimetableRow(departure: "07:00", arrival: "07:26", isNew: false),
                        NoticeTimetableRow(departure: "07:20", arrival: "07:46", isNew: true),
                        NoticeTimetableRow(departure: "07:35", arrival: "08:01", isNew: false)
                    ],
                    note: "* 도로 사정에 따라 도착 시간이 지연될 수 있습니다.",
                    fullScheduleImageURL: nil
                )
            ),
            NoticeItem(
                id: "notice-002",
                title: "[안내] 시스템 정기 점검에 따른 서비스 일시 중단",
                date: "2023.10.20",
                author: "관리자",
                body: ["정기 서버 점검으로 인해 일부 기능이 일시 중단될 수 있습니다."],
                timetableSummary: nil
            ),
            NoticeItem(
                id: "notice-003",
                title: "추석 연휴 기간 셔틀버스 운행 안내",
                date: "2023.09.25",
                author: "관리자",
                body: ["추석 연휴 기간 동안 주말 시간표로 운행됩니다."],
                timetableSummary: nil
            )
        ]
    }

    // MARK: - 헬퍼 뷰

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .tracking(0.3)
            .foregroundStyle(Color(red: 142/255, green: 142/255, blue: 147/255))
            .padding(.horizontal, 12)
    }

    private func iconBox(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(Color(red: 44/255, green: 44/255, blue: 46/255))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func infoNavigationRow(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(.white)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 99/255, green: 99/255, blue: 102/255))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color(red: 56/255, green: 56/255, blue: 58/255))
            .frame(height: 0.5)
            .padding(.leading, 16)
    }

}

// MARK: - View Modifier

private struct SettingsCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(red: 28/255, green: 28/255, blue: 30/255))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private extension View {
    func settingsCard() -> some View {
        modifier(SettingsCardModifier())
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        InfoView()
    }
    .preferredColorScheme(.dark)
}
