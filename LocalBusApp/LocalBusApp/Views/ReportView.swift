import SwiftUI
import PhotosUI
import MessageUI
import UIKit

// MARK: - 시간표 제보 화면

struct ReportView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var description = ""
    @State private var isLoadingPhoto = false
    @State private var photoError: String?

    @State private var isShowingMailComposer = false
    @State private var sendResult: MailResultNotice?
    @State private var showShareSheet = false

    private let maxCharacters = 200
    private let recipientEmail = "jangyubus.app@gmail.com"

    private var canSend: Bool {
        (!isLoadingPhoto && (selectedItem == nil || selectedImage != nil || photoError != nil)) && (selectedImage != nil || !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
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
                uploadSection
                if isLoadingPhoto { ProgressView("사진을 불러오는 중") }
                if let photoError {
                    Text(photoError).font(.footnote).foregroundStyle(.orange)
                }
                if selectedItem != nil || selectedImage != nil {
                    Button("사진 제거", role: .destructive) {
                        selectedItem = nil
                        selectedImage = nil
                        photoError = nil
                    }
                }
                formSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(AmbientBackground())
        .safeAreaInset(edge: .bottom) {
            bottomButton
        }
        .navigationTitle("시간표 제보")
        .navigationBarTitleDisplayMode(.inline)
        .legacyToolbarBackground(HomeDashboardTheme.screenBackground.opacity(0.95))
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
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

    // MARK: - 업로드 섹션

    private var uploadSection: some View {
        PhotosPicker(selection: Binding(get: { selectedItem }, set: { item in
            guard item != selectedItem else { return }
            selectedImage = nil
            photoError = nil
            isLoadingPhoto = item != nil
            selectedItem = item
        }), matching: .images) {
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
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 22))
                                .foregroundStyle(HomeDashboardTheme.primaryText)
                        }
                        VStack(spacing: 4) {
                            Text("시간표 사진 선택")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(HomeDashboardTheme.primaryText)
                            Text("사진 보관함에서 시간표를 선택해주세요")
                                .font(.footnote)
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
        .task(id: selectedItem) {
            let item = selectedItem
            selectedImage = nil
            photoError = nil
            guard let item else { isLoadingPhoto = false; return }
            isLoadingPhoto = true
            defer { if selectedItem == item { isLoadingPhoto = false } }
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { throw CocoaError(.fileReadCorruptFile) }
                guard !Task.isCancelled, selectedItem == item else { return }
                selectedImage = image
            } catch {
                guard !Task.isCancelled, selectedItem == item else { return }
                photoError = "사진을 불러오지 못했습니다. 다른 사진을 선택하거나 설명만 보내주세요."
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
                    .font(.footnote)
                    .foregroundStyle(HomeDashboardTheme.secondaryText)
                    .padding(.top, 1)

                Text("제보해주신 내용은 확인 후 시간표 업데이트에 반영합니다. 확인에 시간이 걸릴 수 있습니다.")
                    .font(.footnote)
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
                Text(MailComposeView.canSendMail ? "메일 작성으로 이동" : "제보 내용 공유")
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
            selectedItem = nil
            selectedImage = nil
            description = ""
        }
    }

    private var shareItems: [Any] {
        var items: [Any] = ["수신: \(recipientEmail)\n제목: \(mailSubject)\n\n\(mailBody)"]
        if let selectedImage { items.append(selectedImage) }
        return items
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
