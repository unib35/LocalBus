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
    @State private var sendResult: MailResultNotice?
    @State private var showShareSheet = false

    private let maxCharacters = 500
    private let recipientEmail = "jangyubus.app@gmail.com"

    private var isReplyEmailValid: Bool {
        let email = replyEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        return email.isEmpty || email.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }

    private var canSend: Bool {
        isReplyEmailValid && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("메일 앱에서 내용을 확인한 뒤 직접 발송합니다.")
                        .font(.footnote).foregroundStyle(HomeDashboardTheme.secondaryText)
                    if !MailComposeView.canSendMail {
                        Text("메일 계정이 없어도 작성 내용을 다른 앱으로 공유할 수 있습니다.")
                            .font(.footnote).foregroundStyle(HomeDashboardTheme.secondaryText)
                        Button("문의 이메일 복사") { UIPasteboard.general.string = recipientEmail }
                            .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                typeSection
                contentSection
                replyEmailSection
                infoBox
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(AmbientBackground())
        .safeAreaInset(edge: .bottom) {
            bottomButton
        }
        .navigationTitle("문의하기")
        .navigationBarTitleDisplayMode(.inline)
        .legacyToolbarBackground(HomeDashboardTheme.screenBackground.opacity(0.95))
        .toolbarColorScheme(nil, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
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
        .alert(
            sendResult?.title ?? "메일 결과",
            isPresented: Binding(
                get: { sendResult != nil },
                set: { if !$0 { sendResult = nil } }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(sendResult?.message ?? "")
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
                    .font(.body)
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
                        .font(.body)
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
                .font(.body)
                .foregroundStyle(HomeDashboardTheme.primaryText)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(height: 52)
                .glassCard(cornerRadius: 12, fallback: HomeDashboardTheme.cardBackground)
                .fallbackCardBorder(cornerRadius: 12, color: HomeDashboardTheme.border)

            if !replyEmail.isEmpty && !isReplyEmailValid {
                Text("이메일 주소 형식을 확인해주세요.")
                    .font(.footnote).foregroundStyle(.orange)
            }
            Text("입력하지 않으면 메일을 보낸 주소로 답변드립니다.")
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
                Text(MailComposeView.canSendMail ? "메일 작성으로 이동" : "작성 내용 공유")
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
            showShareSheet = true
        }
    }

    private func handleMailFinish(_ result: MFMailComposeResult, error: Error?) {
        isShowingMailComposer = false
        sendResult = MailResultNotice.make(result: result, error: error)
        if result == .sent {
            content = ""
            replyEmail = ""
        }
    }

    private var shareItems: [Any] {
        let items: [Any] = ["수신: \(recipientEmail)\n제목: \(mailSubject)\n\n\(mailBody)"]
        return items
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
