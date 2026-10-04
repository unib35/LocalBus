import SwiftUI
import MessageUI
import UIKit

struct MailComposeView: UIViewControllerRepresentable {

    struct Attachment {
        let data: Data
        let mimeType: String
        let fileName: String
    }

    let recipients: [String]
    let subject: String
    let body: String
    let attachments: [Attachment]
    let onFinish: (MFMailComposeResult, Error?) -> Void

    static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients(recipients)
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        for attachment in attachments {
            controller.addAttachmentData(
                attachment.data,
                mimeType: attachment.mimeType,
                fileName: attachment.fileName
            )
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let onFinish: (MFMailComposeResult, Error?) -> Void

        init(onFinish: @escaping (MFMailComposeResult, Error?) -> Void) {
            self.onFinish = onFinish
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true) { [onFinish] in
                onFinish(result, error)
            }
        }
    }
}

/// 작성 창 종료 결과를 성공/보관/실패로 구분한다.
struct MailResultNotice {
    let title: String
    let message: String

    static func make(result: MFMailComposeResult, error: Error?) -> MailResultNotice? {
        switch result {
        case .sent: return MailResultNotice(title: "메일 발송 요청 완료", message: "메일 앱에서 발송을 요청했습니다. 검토 후 답변드리겠습니다.")
        case .saved: return MailResultNotice(title: "임시 저장됨", message: "아직 발송되지 않았습니다. 메일 앱의 임시 보관함에서 이어서 작성해주세요.")
        case .failed: return MailResultNotice(title: "메일 전송 실패", message: error?.localizedDescription ?? "연결을 확인한 뒤 다시 시도해주세요. 작성 내용은 유지됩니다.")
        case .cancelled: return nil
        @unknown default: return nil
        }
    }
}
