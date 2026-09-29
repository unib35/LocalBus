import SwiftUI
import PhotosUI
import MessageUI
import UIKit

// MARK: - 틀린 정보 제보 시트 (디자인 캔버스 QuickReport)
//
// 요금·정류장·이용 안내 옆의 '수정 제보'에서 열린다. 종류와 노선·버스 시각이 미리 채워지고,
// '지금 앱에 나온 정보'를 그대로 보여줘 무엇이 틀렸는지만 적으면 된다. 전송은 메일 작성 창.

enum QuickReportKind: String, CaseIterable, Identifiable {
    case fare = "요금"
    case time = "출발 시각"
    case stops = "정류장"
    case duration = "소요 시간"
    case guide = "이용 안내"
    case other = "기타"

    var id: String { rawValue }

    var placeholder: String {
        switch self {
        case .fare: return "예: 성인 요금이 2,700원이에요"
        case .time: return "예: 07:25에 출발해요"
        case .stops: return "예: 코아상가에는 서지 않아요"
        case .duration: return "예: 출근 시간에는 40분쯤 걸려요"
        case .guide: return "예: 심야버스 승차장이 바뀌었어요"
        case .other: return "예: 공휴일인데 평일 시간표로 나와요"
        }
    }
}

/// 제보 시트에 미리 채울 정보. 버스 상세에서 열면 `info`가 있고, 이용 안내에서 열면 없다.
struct QuickReportContext: Identifiable {
    let entry: QuickReportKind
    let info: BusDetailInfo?

    var id: String { "\(entry.rawValue)|\(info?.departureTime ?? "-")" }

    var contextText: String {
        guard let info else { return "버스 이용 안내" }
        return "\(info.directionDisplayName) · \(info.scheduleTypeLabel) \(info.departureTime) 버스"
    }

    /// "지금 앱에 나온 정보" (없으면 nil)
    func shownText(for kind: QuickReportKind) -> String? {
        guard let info else { return nil }
        switch kind {
        case .fare:
            let base = info.isNightFare ? (info.nightFare ?? info.fare) : info.fare
            var parts = [
                "성인 \(Self.won(base))",
                "청소년 \(Self.won(Int(Double(base) * 0.8)))",
                "어린이 \(Self.won(Int(Double(base) * 0.52)))",
            ]
            if !info.isNightFare, let night = info.nightFare, let start = info.nightFareStartTime {
                parts.append("\(start) 이후 심야 \(Self.won(night))")
            }
            return parts.joined(separator: " · ")
        case .time:
            return "\(info.scheduleTypeLabel) \(info.departureTime) 출발 · \(info.isVia ? "경유" : "직행")"
        case .stops:
            let names = info.stops.map(\.name)
            return names.isEmpty ? nil : names.joined(separator: " → ")
        case .duration:
            // 버스 상세에 보이는 도착 예상과 같은 값을 보여준다
            let minutes = info.estimate?.durationMinutes ?? info.durationMinutes
            let arrival = info.estimate?.arrivalTime ?? info.arrivalTime
            return "\(minutes)분 · \(arrival) \(info.direction.arrivalName) 도착 예상"
        case .guide, .other:
            return nil
        }
    }

    private static func won(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: amount)) ?? "\(amount)") + "원"
    }
}

struct QuickReportView: View {
    let context: QuickReportContext

    @Environment(\.dismiss) private var dismiss
    @State private var kind: QuickReportKind
    @State private var text = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isShowingMailComposer = false
    @State private var isShowingMailUnavailableAlert = false
    @State private var isSent = false

    private let recipientEmail = "jangyubus.app@gmail.com"

    init(context: QuickReportContext) {
        self.context = context
        _kind = State(initialValue: context.entry)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    Group {
                        if isSent {
                            sentBody
                        } else {
                            editingBody
                        }
                    }
                    // 내용이 짧으면 아래 버튼 묶음이 시트 바닥에 붙는다
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
            }
            .background(AppTheme.Color.sheetBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
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
    }

    // MARK: - 작성

    private var editingBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("어떤 정보가 다른가요?")
                    .font(AppTheme.Typography.sheetTitle)
                    .foregroundStyle(AppTheme.Color.primaryText)
                Text(context.contextText)
                    .font(AppTheme.Typography.caption)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }

            FlowLayout(spacing: 8) {
                ForEach(QuickReportKind.allCases) { option in
                    SelectableChip(title: option.rawValue, isSelected: option == kind, height: 40) {
                        kind = option
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
            }
            .padding(.top, 18)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("다른 정보 종류")

            if let shown = context.shownText(for: kind) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("지금 앱에 나온 정보")
                        .font(AppTheme.Typography.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Color.secondaryText)
                    Text(shown)
                        .font(AppTheme.Typography.rowValue.weight(.semibold))
                        .monospacedDigit()
                        .lineSpacing(3)
                        .foregroundStyle(AppTheme.Color.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .sheetTileSurface(cornerRadius: 14)
                .padding(.top, 18)
                .accessibilityElement(children: .combine)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("실제로는 어떤가요? (선택)")
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Color.secondaryText)

                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(kind.placeholder)
                            .font(AppTheme.Typography.rowBody)
                            .foregroundStyle(AppTheme.Color.tertiaryText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $text)
                        .font(AppTheme.Typography.rowBody)
                        .foregroundStyle(AppTheme.Color.primaryText)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                }
                .frame(height: 96)
                .sheetTileSurface(cornerRadius: 14)
            }
            .padding(.top, 18)

            PhotosPicker(selection: $selectedItem, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: selectedImage == nil ? "camera" : "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(selectedImage == nil ? AppTheme.Color.primaryText : AppTheme.Color.accent)
                    Text(selectedImage == nil ? "요금표·시간표 사진 첨부" : "사진 1장 첨부됨 · 바꾸기")
                        .font(AppTheme.Typography.rowValue.weight(.semibold))
                        .foregroundStyle(AppTheme.Color.primaryText)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .sheetTileSurface(cornerRadius: 14)
            }
            .buttonStyle(.plain)
            .padding(.top, 10)

            Spacer(minLength: 18)

            Text("메일 작성 창에 위 내용이 채워져 열려요. 보내기만 누르면 끝나요.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                send()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("제보 보내기")
                }
            }
            .buttonStyle(PrimaryButtonStyle(height: 52))
            .padding(.top, 12)

            NavigationLink {
                ContactView()
            } label: {
                HStack(spacing: 2) {
                    Text("다른 내용은 문의하기로")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Color.secondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 34)
    }

    // MARK: - 보낸 뒤

    private var sentBody: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.accent)
                Text("제보 고마워요")
                    .font(AppTheme.Typography.sheetTitle)
                    .foregroundStyle(AppTheme.Color.primaryText)
                Text("\(kind.rawValue) 정보를 확인한 뒤 앱에 반영할게요")
                    .font(AppTheme.Typography.rowValue)
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 96)
            .accessibilityElement(children: .combine)

            Spacer(minLength: 18)

            Button {
                dismiss()
            } label: {
                Text("닫기")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.primaryButton, style: .continuous)
                            .fill(AppTheme.Color.secondaryButton)
                    )
            }
            .buttonStyle(.plain)

            Button {
                isSent = false
                text = ""
                selectedItem = nil
                selectedImage = nil
            } label: {
                Text("다른 정보도 제보하기")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 34)
    }

    // MARK: - 메일

    private func send() {
        if MailComposeView.canSendMail {
            isShowingMailComposer = true
        } else {
            isShowingMailUnavailableAlert = true
        }
    }

    private func handleMailFinish(_ result: MFMailComposeResult, error: Error?) {
        if result == .sent {
            withAnimation(.easeInOut(duration: 0.2)) { isSent = true }
        }
    }

    private var mailSubject: String {
        var parts = ["[수정 제보] \(kind.rawValue)"]
        if let info = context.info {
            parts.append("\(info.directionDisplayName) \(info.departureTime)")
        }
        return parts.joined(separator: " · ")
    }

    private var mailBody: String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        var lines: [String] = []
        lines.append("종류: \(kind.rawValue)")
        if let info = context.info {
            lines.append("노선: \(info.directionDisplayName)")
            lines.append("버스: \(info.scheduleTypeLabel) \(info.departureTime)")
        } else {
            lines.append("화면: 버스 이용 안내")
        }
        if let shown = context.shownText(for: kind) {
            lines.append("앱에 표시된 정보: \(shown)")
        }
        lines.append("")
        lines.append("실제 정보:")
        lines.append(text.isEmpty ? "(첨부 사진 참고)" : text)
        lines.append("")
        lines.append("---")
        lines.append("앱 버전: \(appVersion)")
        lines.append("기기: \(UIDevice.current.model)")
        lines.append("iOS: \(UIDevice.current.systemVersion)")
        return lines.joined(separator: "\n")
    }

    private var mailAttachments: [MailComposeView.Attachment] {
        guard let image = selectedImage, let data = image.jpegData(compressionQuality: 0.8) else { return [] }
        return [MailComposeView.Attachment(data: data, mimeType: "image/jpeg", fileName: "report-\(Int(Date().timeIntervalSince1970)).jpg")]
    }
}

/// 요금·정류장·이용 안내 제목 옆에 붙는 작은 '수정 제보' 링크. 회색 글자, 터치 영역 44px.
struct EditReportLink: View {
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .semibold))
                Text("수정 제보")
                    .font(AppTheme.Typography.caption.weight(.semibold))
            }
            .foregroundStyle(AppTheme.Color.secondaryText)
            .padding(.horizontal, 8)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview {
    QuickReportView(context: QuickReportContext(entry: .fare, info: nil))
        .preferredColorScheme(.dark)
}
