import SwiftUI
import PhotosUI
import MessageUI
import UIKit

// MARK: - 시간표 제보 화면 (디자인 캔버스 개선안)
//
// 점선 업로드 박스 하나 대신 "사진 찍기 / 앨범에서 선택" 두 버튼. 어느 노선 제보인지 칩으로 고른다.
// 보내면 메일 앱이 열리고 기기 정보가 함께 담긴다는 것을 미리 알린다.

struct ReportView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedDirection: RouteDirection = .jangyuToSasang
    @State private var description = ""

    @State private var isShowingCamera = false
    @State private var isShowingMailComposer = false
    @State private var isShowingMailUnavailableAlert = false
    @State private var sendResultMessage: String?

    private let maxCharacters = 200
    private let recipientEmail = "jangyubus.app@gmail.com"

    private var canSend: Bool {
        selectedImage != nil || !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                header
                photoSection
                routeSection
                descriptionSection

                Text("보내면 메일 앱이 열립니다 · 앱 버전과 기기 정보가 함께 담깁니다")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
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
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker { image in
                selectedImage = image
            }
            .ignoresSafeArea()
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

    // MARK: - 헤더

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("시간표 제보")
                .font(AppTheme.Typography.screenTitle)
                .foregroundStyle(AppTheme.Color.primaryText)
            Text("정류장에 붙은 새 시간표를 찍어 보내주세요. 확인 후 앱에 반영됩니다")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 사진

    @ViewBuilder
    private var photoSection: some View {
        if let image = selectedImage {
            VStack(alignment: .leading, spacing: 10) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.surface, style: .continuous))
                    .accessibilityLabel("첨부한 시간표 사진")

                Button("사진 빼기") {
                    selectedImage = nil
                    selectedItem = nil
                }
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Color.secondaryText)
                .frame(minHeight: 44)
            }
        } else {
            HStack(spacing: 10) {
                if isCameraAvailable {
                    Button {
                        isShowingCamera = true
                    } label: {
                        uploadTile(systemImage: "camera", title: "사진 찍기")
                    }
                    .buttonStyle(.plain)
                }

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    uploadTile(systemImage: "photo.on.rectangle", title: "앨범에서 선택")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func uploadTile(systemImage: String, title: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(AppTheme.Color.primaryText)
            Text(title)
                .font(AppTheme.Typography.buttonLabel)
                .foregroundStyle(AppTheme.Color.primaryText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 108)
        .surfaceCard(interactive: true)
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.surface, style: .continuous))
    }

    // MARK: - 노선

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("어느 노선인가요?")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Color.secondaryText)

            FlowLayout(spacing: 8) {
                ForEach(RouteDirection.allCases, id: \.self) { direction in
                    SelectableChip(
                        title: direction.displayName,
                        isSelected: selectedDirection == direction,
                        height: 36,
                        action: { selectedDirection = direction }
                    )
                }
            }
        }
    }

    // MARK: - 설명

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("무엇이 바뀌었나요? (선택)")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Color.secondaryText)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $description)
                    .font(AppTheme.Typography.rowBody)
                    .foregroundStyle(AppTheme.Color.primaryText)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 11)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                    .frame(minHeight: 120)
                    .surfaceCard()
                    .onChange(of: description) { newValue in
                        if newValue.count > maxCharacters {
                            description = String(newValue.prefix(maxCharacters))
                        }
                    }

                if description.isEmpty {
                    Text("예: 22:40 막차가 없어졌어요")
                        .font(AppTheme.Typography.rowBody)
                        .foregroundStyle(AppTheme.Color.secondaryText)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }

                Text("\(description.count) / \(maxCharacters)")
                    .font(AppTheme.Typography.footnote)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 14)
                    .padding(.bottom, 12)
                    .frame(minHeight: 120)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - 하단 버튼

    private var bottomButton: some View {
        Button {
            presentMailComposer()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "paperplane")
                    .font(.system(size: 16, weight: .semibold))
                Text("제보 보내기")
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
        "[장유시외버스] 시간표 변경 제보 · \(selectedDirection.displayName)"
    }

    private var mailBody: String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        var lines: [String] = []
        lines.append("안녕하세요, 시간표 변경 제보드립니다.")
        lines.append("")
        lines.append("[노선] \(selectedDirection.displayName)")
        lines.append("")
        lines.append("[바뀐 내용]")
        lines.append(trimmedDescription.isEmpty ? "(작성된 설명 없음)" : trimmedDescription)
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

// MARK: - 카메라

/// 시스템 카메라로 사진 한 장을 찍는다.
struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: { dismiss() })
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let dismiss: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, dismiss: @escaping () -> Void) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ReportView()
    }
    .preferredColorScheme(.dark)
}
