import SwiftUI

/// 앱 정보 화면
struct InfoView: View {
    @Environment(\.dismiss) private var dismiss

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        NavigationStack {
            List {
                // 앱 정보 섹션
                Section {
                    appInfoRow
                } header: {
                    Text("앱 정보")
                }

                // 시간표 정보 섹션
                Section {
                    infoRow(title: "노선", value: "장유 ↔ 사상")
                    infoRow(title: "운행사", value: "시외버스")
                } header: {
                    Text("시간표 정보")
                }

                // 문의 섹션
                Section {
                    feedbackButton
                } header: {
                    Text("문의")
                } footer: {
                    Text("시간표 오류나 개선 사항이 있으면 알려주세요.")
                }

                // 법적 고지 섹션
                Section {
                    disclaimerRow
                } header: {
                    Text("법적 고지")
                }
            }
            .navigationTitle("정보")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - 앱 정보

    private var appInfoRow: some View {
        HStack {
            Image(systemName: "bus.fill")
                .font(.title2)
                .foregroundStyle(.primary)
                .frame(width: 50, height: 50)
                .background(Color(uiColor: .tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text("LocalBus")
                    .font(.headline)
                Text("버전 \(appVersion) (\(buildNumber))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 8)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 정보 행

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 제보하기 버튼

    private var feedbackButton: some View {
        Button {
            sendFeedbackEmail()
        } label: {
            HStack {
                Image(systemName: "envelope")
                    .foregroundStyle(.primary)
                Text("시간표 오류 제보하기")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.primary)
    }

    // MARK: - 법적 고지

    private var disclaimerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("본 앱에서 제공하는 시간표는 참고용입니다.")
            Text("실제 운행 시간은 기상 상황, 도로 상태 등에 따라 변경될 수 있습니다.")
            Text("정확한 시간표는 운행사에 문의해 주세요.")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - 메일 전송

    private func sendFeedbackEmail() {
        let email = "help@localbus.com"
        let subject = "[LocalBus] 시간표 오류 제보"
        let body = """

        ---
        앱 버전: \(appVersion) (\(buildNumber))
        기기: \(UIDevice.current.model)
        iOS: \(UIDevice.current.systemVersion)
        """

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    InfoView()
}
