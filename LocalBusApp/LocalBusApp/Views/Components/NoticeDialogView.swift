import SwiftUI

// MARK: - 중요 공지 다이얼로그 (디자인 캔버스 NoticeDialog)
//
// 임시 운휴·시간표 변경 같은 중요 공지에만 쓴다. 화면 아래쪽만 덮어 다음 버스 카드는 가리지 않는다.
// 버튼은 셋: 내용 보기(기본), 오늘 하루 보지 않기, 닫기. 닫기만 누르면 다음 실행 때 다시 뜬다.

struct NoticeDialogView: View {
    let notice: NoticeItem
    let onOpen: () -> Void
    let onSnooze: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(notice.category)
                    .font(AppTheme.Typography.footnote.weight(.bold))
                    .foregroundStyle(AppTheme.Color.screenBackground)
                    .padding(.horizontal, 9)
                    .frame(height: 22)
                    .background(Capsule().fill(AppTheme.Color.primaryText))
                Text(notice.date)
                    .font(AppTheme.Typography.footnote)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }

            Text(notice.title)
                .font(AppTheme.Typography.sheetTitle)
                .lineSpacing(3)
                .foregroundStyle(AppTheme.Color.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            if let first = notice.body.first {
                Text(first)
                    .font(AppTheme.Typography.rowValue)
                    .lineSpacing(4)
                    .foregroundStyle(AppTheme.Color.primaryText.opacity(0.83))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }

            Spacer(minLength: 16)

            Button("내용 보기", action: onOpen)
                .buttonStyle(PrimaryButtonStyle(height: 52))

            HStack {
                Button("오늘 하루 보지 않기", action: onSnooze)
                    .font(AppTheme.Typography.rowValue.weight(.semibold))
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .frame(height: 48)
                    .padding(.horizontal, 8)
                    .padding(.leading, -8)
                Spacer()
                Button("닫기", action: onClose)
                    .font(AppTheme.Typography.rowValue.weight(.semibold))
                    .foregroundStyle(AppTheme.Color.primaryText)
                    .frame(height: 48)
                    .padding(.horizontal, 8)
                    .padding(.trailing, -8)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 8)
        .background(AppTheme.Color.surfaceSecondary.ignoresSafeArea())
        .presentationDetents([.height(370)])
        .presentationDragIndicator(.hidden)
    }
}

#Preview {
    Color.black
        .sheet(isPresented: .constant(true)) {
            NoticeDialogView(
                notice: NoticeItem(
                    id: "n", title: "추석 연휴에는 주말 시간표로 운행해요", date: "9월 21일", author: "관리자",
                    body: ["9월 28일(월)부터 30일(수)까지 주말·공휴일 시간표가 적용돼요. 평일보다 운행 횟수가 적으니 출발 전에 확인해 주세요."],
                    categoryLabel: "시간표 변경"
                ),
                onOpen: {}, onSnooze: {}, onClose: {}
            )
        }
        .preferredColorScheme(.dark)
}
