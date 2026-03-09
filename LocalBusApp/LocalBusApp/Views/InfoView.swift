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

    @State private var showingPrivacyPolicy = false
    @State private var showingNotice = false

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
        .sheet(isPresented: $showingNotice) {
            noticeSheet
        }
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
                Button { showingNotice = true } label: {
                    infoNavigationRow("공지사항")
                }
                .buttonStyle(.plain)

                rowDivider

                // 문의하기
                Button { sendFeedbackEmail() } label: {
                    infoNavigationRow("문의하기")
                }
                .buttonStyle(.plain)

                rowDivider

                // 이용약관 및 개인정보처리방침
                Button { openPrivacyPolicy() } label: {
                    infoNavigationRow("이용약관 및 개인정보처리방침")
                }
                .buttonStyle(.plain)
            }
            .settingsCard()
        }
    }

    // MARK: - 공지사항 시트

    private var noticeSheet: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("현재 공지사항이 없습니다.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(red: 142/255, green: 142/255, blue: 147/255))
                    Spacer()
                }
                .padding(.top, 40)
            }
            .navigationTitle("공지사항")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium])
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

    // MARK: - 액션

    private func sendFeedbackEmail() {
        let email = "help@localbus.com"
        let subject = "[LocalBus] 시간표 오류 제보"
        let body = "\n\n---\n앱 버전: \(appVersion)\n기기: \(UIDevice.current.model)\niOS: \(UIDevice.current.systemVersion)"
        let encoded = "mailto:\(email)?subject=\(subject.urlEncoded)&body=\(body.urlEncoded)"
        if let url = URL(string: encoded) {
            UIApplication.shared.open(url)
        }
    }

    private func openPrivacyPolicy() {
        if let url = URL(string: "https://jongmini.github.io/LocalBus/privacy") {
            UIApplication.shared.open(url)
        }
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

// MARK: - String Extension

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        InfoView()
    }
    .preferredColorScheme(.dark)
}
