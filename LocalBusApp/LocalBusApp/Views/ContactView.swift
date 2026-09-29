import SwiftUI
import MessageUI
import UIKit

// MARK: - 문의 유형

private enum ContactType: String, CaseIterable {
    case schedule = "버스 시간"
    case feature = "앱 기능"
    case other = "기타"

    /// 메일 제목에 쓰는 정식 이름
    var mailLabel: String {
        switch self {
        case .schedule: return "버스 시간 관련"
        case .feature: return "앱 기능 문의"
        case .other: return "기타"
        }
    }
}

// MARK: - 문의하기 화면 (디자인 캔버스 개선안)
//
// 세그먼트 대신 짧은 라벨의 칩, 안내 박스 대신 한 줄 설명. 전송 방식(메일 앱)을 부제에서 먼저 알린다.

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
            VStack(alignment: .leading, spacing: 24) {
                header
                typeSection
                contentSection
                replyEmailSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(AmbientBackground())
        .safeAreaInset(edge: .bottom) {
            bottomButton
        }
        .navigationBarTitleDisplayMode(.inline)
        .legacyToolbarBackground(AppTheme.Color.screenBackground.opacity(0.95))
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

    // MARK: - 헤더

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("문의하기")
                .font(AppTheme.Typography.screenTitle)
                .foregroundStyle(AppTheme.Color.primaryText)
            Text("메일 앱으로 보내지며, 답장은 입력한 이메일로 드려요")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.Color.secondaryText)
        }
    }

    // MARK: - 문의 유형 섹션

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("문의 유형")
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Color.secondaryText)

            HStack(spacing: 8) {
                ForEach(ContactType.allCases, id: \.self) { type in
                    SelectableChip(
                        title: type.rawValue,
                        isSelected: selectedType == type,
                        action: { selectedType = type }
                    )
                }
            }
        }
    }

    // MARK: - 내용 섹션

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("내용")
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Color.secondaryText)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $content)
                    .font(AppTheme.Typography.rowBody)
                    .foregroundStyle(AppTheme.Color.primaryText)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 11)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                    .frame(minHeight: 160)
                    .surfaceCard()
                    .onChange(of: content) { newValue in
                        if newValue.count > maxCharacters {
                            content = String(newValue.prefix(maxCharacters))
                        }
                    }

                if content.isEmpty {
                    Text("예: 07:20 버스가 실제로는 07:25에 출발해요")
                        .font(AppTheme.Typography.rowBody)
                        .foregroundStyle(AppTheme.Color.secondaryText)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }

                Text("\(content.count) / \(maxCharacters)")
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.tertiaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 14)
                    .padding(.bottom, 12)
                    .frame(minHeight: 160)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - 회신받을 이메일 섹션

    private var replyEmailSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("회신받을 이메일 (선택)")
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Color.secondaryText)

            ZStack(alignment: .leading) {
                if replyEmail.isEmpty {
                    Text("example@email.com")
                        .font(AppTheme.Typography.rowBody)
                        .foregroundStyle(AppTheme.Color.secondaryText)
                        .padding(.horizontal, 16)
                        .allowsHitTesting(false)
                }
                TextField("회신받을 이메일", text: $replyEmail)
                    .labelsHidden()
                    .font(AppTheme.Typography.rowBody)
                    .foregroundStyle(AppTheme.Color.primaryText)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
            }
            .frame(height: 52)
            .surfaceCard(cornerRadius: 14)

            Text("검토 후 이메일로 답변 드려요. 유형을 정확히 고르면 더 빨리 답할 수 있어요.")
                .font(.system(size: 13))
                .lineSpacing(3)
                .foregroundStyle(AppTheme.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 하단 버튼

    private var bottomButton: some View {
        Button {
            presentMailComposer()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "envelope")
                    .font(.system(size: 16, weight: .semibold))
                Text("메일로 보내기")
            }
        }
        .buttonStyle(PrimaryButtonStyle(height: 52))
        .disabled(!canSend)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(AppTheme.Color.screenBackground.opacity(0.95))
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
        "[장유시외버스] \(selectedType.mailLabel)"
    }

    private var mailBody: String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = replyEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        var lines: [String] = []
        lines.append("[문의 유형] \(selectedType.mailLabel)")
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
