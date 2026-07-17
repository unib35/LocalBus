import SwiftUI
import MessageUI
import UIKit

// MARK: - 문의 유형

private enum ContactType: String, CaseIterable {
    case schedule = "버스 시간 관련"
    case feature = "앱 기능 문의"
    case other = "기타"
}

// MARK: - 문의하기 화면

struct ContactView: View {
    @State private var selectedType: ContactType = .schedule
    @State private var content = ""
    @State private var replyEmail = ""

    @State private var isShowingMailComposer = false
    @State private var isShowingMailUnavailableAlert = false
    @State private var sendResultMessage: String?

    private let maxCharacters = 500
    private let recipientEmail = "jangyubus.app@gmail.com"

    private var canSend: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                typeSection
                contentSection
                replyEmailSection
                infoBox
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(HomeDashboardTheme.screenBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            bottomButton
        }
        .navigationTitle("문의하기")
        .navigationBarTitleDisplayMode(.inline)
        .legacyToolbarBackground(HomeDashboardTheme.screenBackground.opacity(0.95))
        .toolbarColorScheme(nil, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $isShowingMailComposer) {
            MailComposeView(
                recipients: [recipientEmail],
                subject: mailSubject,
                body: mailBody,
                attachments: [],
                onFinish: handleMailFinish
            )
            .ignoresSafeArea()
        }
        .alert("메일 앱을 사용할 수 없어요", isPresented: $isShowingMailUnavailableAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("기본 메일 앱에 계정이 설정되어 있지 않습니다. 설정 → 메일에서 계정을 추가한 뒤 다시 시도해주세요.\n또는 \(recipientEmail) 으로 직접 보내주실 수 있어요.")
        }
        .alert(
            "문의 전송 완료",
            isPresented: Binding(
                get: { sendResultMessage != nil },
                set: { if !$0 { sendResultMessage = nil } }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(sendResultMessage ?? "")
        }
    }

    // MARK: - 문의 유형 섹션

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("문의 유형")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(HomeDashboardTheme.secondaryText)

            Picker("문의 유형", selection: $selectedType) {
                ForEach(ContactType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - 내용 섹션

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("내용")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(HomeDashboardTheme.secondaryText)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $content)
                    .font(.system(size: 16))
                    .foregroundStyle(HomeDashboardTheme.primaryText)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 11)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                    .frame(minHeight: 180)
                    .glassCard(cornerRadius: 12, fallback: HomeDashboardTheme.cardBackground)
                    .fallbackCardBorder(cornerRadius: 12, color: HomeDashboardTheme.border)
                    .onChange(of: content) { newValue in
                        if newValue.count > maxCharacters {
                            content = String(newValue.prefix(maxCharacters))
                        }
                    }

                if content.isEmpty {
                    Text("문의 내용을 입력해주세요.")
                        .font(.system(size: 16))
                        .foregroundStyle(HomeDashboardTheme.secondaryText)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(content.count)/\(maxCharacters)")
                            .font(.system(size: 12))
                            .foregroundStyle(HomeDashboardTheme.secondaryText)
                            .padding(.trailing, 12)
                            .padding(.bottom, 12)
                    }
                }
                .frame(minHeight: 180)
            }
        }
    }

    // MARK: - 회신받을 이메일 섹션

    private var replyEmailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("회신받을 이메일 (선택)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(HomeDashboardTheme.secondaryText)

            TextField("", text: $replyEmail, prompt: Text("example@email.com").foregroundColor(HomeDashboardTheme.secondaryText))
                .font(.system(size: 16))
                .foregroundStyle(HomeDashboardTheme.primaryText)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(height: 52)
                .glassCard(cornerRadius: 12, fallback: HomeDashboardTheme.cardBackground)
                .fallbackCardBorder(cornerRadius: 12, color: HomeDashboardTheme.border)

            Text("답변받을 이메일 주소를 입력하면 더 빠르게 회신받을 수 있어요.")
                .font(.system(size: 12))
                .foregroundStyle(HomeDashboardTheme.secondaryText)
        }
    }

    // MARK: - 안내 박스

    private var infoBox: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(HomeDashboardTheme.secondaryText)
                .padding(.top, 2)

            Text("문의 내용은 검토 후 이메일로 답변 드립니다. 빠른 답변을 위해 문의 유형을 정확히 선택해 주세요.")
                .font(.system(size: 14))
                .foregroundStyle(HomeDashboardTheme.secondaryText)
                .lineSpacing(3)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 8, fallback: HomeDashboardTheme.cardBackground)
        .fallbackCardBorder(cornerRadius: 8, color: HomeDashboardTheme.border, lineWidth: 0.5)
    }

    // MARK: - 하단 버튼

    private var bottomButton: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(HomeDashboardTheme.border)
                .frame(height: 0.5)

            Button {
                presentMailComposer()
            } label: {
                Text("보내기")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.Color.primaryForeground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(canSend ? HomeDashboardTheme.primaryBlue : HomeDashboardTheme.primaryBlue.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .padding(.horizontal, 16)
            .padding(.top, 17)
            .padding(.bottom, 32)
        }
        .background(HomeDashboardTheme.screenBackground)
    }

    // MARK: - 액션

    private func presentMailComposer() {
        guard canSend else { return }

        if MailComposeView.canSendMail {
            isShowingMailComposer = true
        } else {
            isShowingMailUnavailableAlert = true
        }
    }

    private func handleMailFinish(_ result: MFMailComposeResult, error: Error?) {
        switch result {
        case .sent:
            sendResultMessage = "문의를 보내주셔서 감사합니다. 검토 후 이메일로 답변 드리겠습니다."
            content = ""
            replyEmail = ""
        case .saved:
            sendResultMessage = "임시 보관함에 저장되었습니다."
        case .failed:
            sendResultMessage = "전송에 실패했습니다.\n\(error?.localizedDescription ?? "잠시 후 다시 시도해주세요.")"
        case .cancelled:
            break
        @unknown default:
            break
        }
    }

    // MARK: - 메일 내용

    private var mailSubject: String {
        "[장유시외버스] \(selectedType.rawValue)"
    }

    private var mailBody: String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = replyEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        var lines: [String] = []
        lines.append("[문의 유형] \(selectedType.rawValue)")
        lines.append("")
        lines.append("[문의 내용]")
        lines.append(trimmedContent.isEmpty ? "(작성된 내용 없음)" : trimmedContent)
        lines.append("")
        lines.append("[회신받을 이메일]")
        lines.append(trimmedEmail.isEmpty ? "(미입력)" : trimmedEmail)
        lines.append("")
        lines.append("---")
        lines.append("앱 버전: \(appVersion) (\(buildNumber))")
        lines.append("기기: \(UIDevice.current.model)")
        lines.append("iOS: \(UIDevice.current.systemVersion)")

        return lines.joined(separator: "\n")
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ContactView()
    }
    .preferredColorScheme(.dark)
}
