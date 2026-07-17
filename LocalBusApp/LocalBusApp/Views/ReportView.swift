import SwiftUI
import PhotosUI
import MessageUI
import UIKit

// MARK: - 시간표 제보 화면

struct ReportView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var description = ""

    @State private var isShowingMailComposer = false
    @State private var isShowingMailUnavailableAlert = false
    @State private var sendResultMessage: String?

    private let maxCharacters = 200
    private let recipientEmail = "jangyubus.app@gmail.com"

    private var canSend: Bool {
        selectedImage != nil || !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                uploadSection
                formSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(HomeDashboardTheme.screenBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            bottomButton
        }
        .navigationTitle("시간표 제보")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(HomeDashboardTheme.screenBackground.opacity(0.95), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $isShowingMailComposer) {
            MailComposeView(
                recipients: [recipientEmail],
                subject: mailSubject,
                body: mailBody,
                attachments: mailAttachments,
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
            "제보 전송 완료",
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

    // MARK: - 업로드 섹션

    private var uploadSection: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            ZStack {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipped()
                } else {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(HomeDashboardTheme.border)
                                .frame(width: 60, height: 60)
                            Image(systemName: "camera.badge.plus")
                                .font(.system(size: 22))
                                .foregroundStyle(HomeDashboardTheme.primaryText)
                        }
                        VStack(spacing: 4) {
                            Text("사진 업로드")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(HomeDashboardTheme.primaryText)
                            Text("변경된 시간표 사진을 찍어주세요")
                                .font(.system(size: 13))
                                .foregroundStyle(HomeDashboardTheme.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 52)
                }
            }
            .glassCard(cornerRadius: 12, fallback: HomeDashboardTheme.cardBackground, interactive: true)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        HomeDashboardTheme.border,
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            )
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
    }

    // MARK: - 폼 섹션

    private var formSection: some View {
        VStack(spacing: 20) {
            // 텍스트 입력
            VStack(alignment: .leading, spacing: 8) {
                Text("추가 설명 (선택 사항)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(HomeDashboardTheme.secondaryText)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $description)
                        .font(.system(size: 15))
                        .foregroundStyle(HomeDashboardTheme.primaryText)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 36)
                        .frame(minHeight: 148)
                        .glassCard(cornerRadius: 10, fallback: HomeDashboardTheme.cardBackground)
                        .fallbackCardBorder(cornerRadius: 10, color: HomeDashboardTheme.border)
                        .onChange(of: description) { newValue in
                            if newValue.count > maxCharacters {
                                description = String(newValue.prefix(maxCharacters))
                            }
                        }

                    if description.isEmpty {
                        Text("변경된 내용에 대해 간략히 적어주세요.")
                            .font(.system(size: 15))
                            .foregroundStyle(HomeDashboardTheme.tertiaryText)
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .allowsHitTesting(false)
                    }

                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("\(description.count)/\(maxCharacters)")
                                .font(.system(size: 11))
                                .foregroundStyle(HomeDashboardTheme.tertiaryText)
                                .padding(.trailing, 12)
                                .padding(.bottom, 10)
                        }
                    }
                    .frame(minHeight: 148)
                }
            }

            // 안내 박스
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(HomeDashboardTheme.secondaryText)
                    .padding(.top, 1)

                Text("사용자님의 제보는 검토 후 서비스에 즉시 반영됩니다. 정확한 정보 공유를 위해 노력해주셔서 감사합니다.")
                    .font(.system(size: 13))
                    .foregroundStyle(HomeDashboardTheme.secondaryText)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 8, fallback: HomeDashboardTheme.cardBackground)
            .fallbackCardBorder(cornerRadius: 8, color: HomeDashboardTheme.border)
        }
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
                Text("제보 보내기")
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
            sendResultMessage = "소중한 제보 감사합니다. 검토 후 빠르게 반영하겠습니다."
            selectedItem = nil
            selectedImage = nil
            description = ""
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
        "[장유시외버스] 시간표 변경 제보"
    }

    private var mailBody: String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        var lines: [String] = []
        lines.append("안녕하세요, 시간표 변경 제보드립니다.")
        lines.append("")

        if trimmedDescription.isEmpty {
            lines.append("[추가 설명]")
            lines.append("(작성된 설명 없음)")
        } else {
            lines.append("[추가 설명]")
            lines.append(trimmedDescription)
        }

        lines.append("")
        lines.append("---")
        lines.append("앱 버전: \(appVersion) (\(buildNumber))")
        lines.append("기기: \(UIDevice.current.model)")
        lines.append("iOS: \(UIDevice.current.systemVersion)")

        return lines.joined(separator: "\n")
    }

    private var mailAttachments: [MailComposeView.Attachment] {
        guard let image = selectedImage,
              let data = image.jpegData(compressionQuality: 0.8) else {
            return []
        }
        let timestamp = Int(Date().timeIntervalSince1970)
        return [
            MailComposeView.Attachment(
                data: data,
                mimeType: "image/jpeg",
                fileName: "timetable-\(timestamp).jpg"
            )
        ]
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ReportView()
    }
    .preferredColorScheme(.dark)
}
