import SwiftUI

// MARK: - 공지사항 목록 뷰 (디자인 캔버스 개선안)
//
// 제목은 두 줄까지 허용, NEW 캡슐 대신 읽지 않음 점, 작성자 대신 카테고리 라벨.
// 최신 공지는 본문 첫 문장을 미리 보여준다.

struct NoticeListView: View {
    let notices: [NoticeItem]

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("공지사항")
                        .font(AppTheme.Typography.screenTitle)
                        .foregroundStyle(AppTheme.Color.primaryText)
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    ForEach(Array(notices.enumerated()), id: \.element.id) { index, notice in
                        NavigationLink(destination: NoticeDetailView(notice: notice)) {
                            noticeRow(notice, showsPreview: index == 0)
                        }
                        .buttonStyle(.plain)

                        if index < notices.count - 1 {
                            RowDivider(leadingInset: 0)
                        }
                    }

                    Text("시간표가 바뀌면 여기와 푸시 알림으로 알려드려요")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Color.tertiaryText)
                        .padding(.top, 24)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .softScrollEdge()
        }
        .navigationBarTitleDisplayMode(.inline)
        .legacyToolbarBackground(AppTheme.Color.screenBackground)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Notice Row

    private func noticeRow(_ notice: NoticeItem, showsPreview: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(notice.isNew ? AppTheme.Color.accent : Color.clear)
                .frame(width: 6, height: 6)
                .padding(.top, 8)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(notice.title.replacingOccurrences(of: "\n", with: " "))
                    .font(AppTheme.Typography.rowTitle)
                    .foregroundStyle(AppTheme.Color.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(notice.date) · \(notice.category)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Color.secondaryText)

                if showsPreview, let preview = notice.body.first, !preview.isEmpty {
                    Text(preview)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Color.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.Color.secondaryText)
                .padding(.top, 4)
        }
        .padding(.vertical, 16)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(notice.isNew ? "읽지 않음, " : "")\(notice.title), \(notice.date), \(notice.category)")
    }
}

// MARK: - 카테고리 라벨

extension NoticeItem {
    /// 제목에서 유추한 카테고리. 데이터에 카테고리가 생기면 그 값으로 바꾼다.
    var category: String {
        if title.contains("시간표") { return "시간표 변경" }
        if title.contains("점검") { return "점검 안내" }
        if title.contains("연휴") || title.contains("운행") { return "운행 안내" }
        return "공지"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NoticeListView(
            notices: [
                NoticeItem(
                    id: "notice-001",
                    title: "2025년 8월 25일부 운행 시간표 변경 안내",
                    date: "2025.08.14",
                    author: "관리자",
                    isNew: true,
                    body: ["장유-사상 시외버스 운행 시간표가 2025년 8월 25일부로 일부 변경됩니다."],
                    timetableSummary: nil
                ),
                NoticeItem(
                    id: "notice-002",
                    title: "[안내] 시스템 정기 점검에 따른 서비스 일시 중단",
                    date: "2023.10.20",
                    author: "관리자",
                    body: ["정기 점검 안내입니다."],
                    timetableSummary: nil
                ),
                NoticeItem(
                    id: "notice-003",
                    title: "추석 연휴 기간 셔틀버스 운행 안내",
                    date: "2023.09.25",
                    author: "관리자",
                    body: ["추석 연휴 운행 안내입니다."],
                    timetableSummary: nil
                )
            ]
        )
    }
    .preferredColorScheme(.dark)
}
