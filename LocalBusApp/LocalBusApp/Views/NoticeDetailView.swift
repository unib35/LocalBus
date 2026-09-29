import SwiftUI
import Kingfisher

// MARK: - 공지사항 데이터 모델

struct NoticeItem: Identifiable {
    let id: String
    let title: String
    let date: String
    let author: String
    let isNew: Bool
    let body: [String]
    let timetableSummary: NoticeTimetableSummary?
    /// 데이터에 명시된 카테고리. 없으면 제목에서 유추한다 (`category`).
    let categoryLabel: String?

    init(
        id: String, title: String, date: String, author: String,
        isNew: Bool = false, body: [String],
        timetableSummary: NoticeTimetableSummary? = nil,
        categoryLabel: String? = nil
    ) {
        self.id = id; self.title = title; self.date = date
        self.author = author; self.isNew = isNew
        self.body = body; self.timetableSummary = timetableSummary
        self.categoryLabel = categoryLabel
    }
}

struct NoticeTimetableSummary {
    let effectiveDate: String
    let departureLabel: String
    let arrivalLabel: String
    let rows: [NoticeTimetableRow]
    let note: String?
    let fullScheduleImageURL: URL?
}

struct NoticeTimetableRow: Identifiable {
    let id = UUID()
    let departure: String
    let arrival: String
    let isNew: Bool
}

// MARK: - 공지사항 상세 뷰 (디자인 캔버스 개선안)
//
// 시스템 내비게이션 바(뒤로가기)를 그대로 쓰고, 카드 테두리·그림자 없이
// 제목 → 메타 → 본문 → 변경 시간표(2차 서피스) 순으로 읽힌다.

struct NoticeDetailView: View {
    let notice: NoticeItem

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    titleSection
                    bodySection
                        .padding(.top, 24)
                    if let summary = notice.timetableSummary {
                        timetableCard(summary)
                            .padding(.top, 28)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .softScrollEdge()
        }
        .navigationBarTitleDisplayMode(.inline)
        .legacyToolbarBackground(AppTheme.Color.screenBackground.opacity(0.95))
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(notice.title.replacingOccurrences(of: "\n", with: " "))
                .font(AppTheme.Typography.sheetTitle)
                .foregroundStyle(AppTheme.Color.primaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(notice.date) · \(notice.category)")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Color.secondaryText)
        }
    }

    // MARK: - Body

    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(notice.body.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(AppTheme.Typography.rowBody)
                    .foregroundStyle(AppTheme.Color.primaryText)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Timetable Card

    private func timetableCard(_ summary: NoticeTimetableSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("변경 시간표")
                    .font(AppTheme.Typography.groupTitle)
                    .foregroundStyle(AppTheme.Color.primaryText)
                Spacer()
                LabelChip(text: "\(summary.effectiveDate) 시행")
            }

            scheduleTable(summary)

            if let note = summary.note {
                Text(note)
                    .font(AppTheme.Typography.footnote)
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let url = summary.fullScheduleImageURL {
                fullScheduleImage(url: url)
            }
        }
    }

    private func scheduleTable(_ summary: NoticeTimetableSummary) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(summary.departureLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(summary.arrivalLabel)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(AppTheme.Typography.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.Color.secondaryText)
            .padding(.horizontal, 16)
            .frame(height: 36)

            RowDivider()

            ForEach(Array(summary.rows.enumerated()), id: \.element.id) { index, row in
                scheduleRow(row)
                if index < summary.rows.count - 1 {
                    RowDivider()
                }
            }
        }
        .surfaceCard()
    }

    private func scheduleRow(_ row: NoticeTimetableRow) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                // 강조색은 "지금 탈 버스"에만 쓴다. 바뀐 시각은 라벨로 알린다.
                Text(row.departure)
                    .font(AppTheme.Typography.rowTime)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.primaryText)
                if row.isNew {
                    LabelChip(text: "변경")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(row.arrival)
                .font(AppTheme.Typography.rowValue)
                .monospacedDigit()
                .foregroundStyle(AppTheme.Color.secondaryText)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.departure) 출발, \(row.arrival) 도착\(row.isNew ? ", 변경된 시간" : "")")
    }

    // MARK: - Full Schedule Image

    private func fullScheduleImage(url: URL) -> some View {
        KFImage(url)
            .placeholder {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.surface, style: .continuous)
                        .fill(AppTheme.Color.surface)
                    ProgressView()
                        .tint(AppTheme.Color.secondaryText)
                }
                .frame(height: 200)
            }
            .fade(duration: 0.3)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.surface, style: .continuous))
            .accessibilityLabel("전체 시간표 이미지")
    }
}

// MARK: - Preview

#Preview {
    let sample = NoticeItem(
        id: "notice-001",
        title: "2025년 8월 25일부\n운행 시간표 변경 안내",
        date: "2025.08.14",
        author: "관리자",
        body: [
            "안녕하세요. 장유-사상 시외버스 운행 시간표가 2025년 8월 25일부로 일부 변경됩니다.",
            "이번 변경은 최근 출퇴근 시간대의 교통 혼잡도 증가와 이용객 수요 변화를 반영하여 더 효율적인 배차 간격을 제공하기 위함입니다. 이용에 착오 없으시길 바랍니다.",
            "자세한 변경 시간표는 아래를 참고해 주시기 바랍니다."
        ],
        timetableSummary: NoticeTimetableSummary(
            effectiveDate: "2025.08.25",
            departureLabel: "장유 출발",
            arrivalLabel: "사상 도착",
            rows: [
                NoticeTimetableRow(departure: "06:20", arrival: "06:46", isNew: false),
                NoticeTimetableRow(departure: "06:40", arrival: "07:06", isNew: true),
                NoticeTimetableRow(departure: "07:00", arrival: "07:26", isNew: false),
                NoticeTimetableRow(departure: "07:20", arrival: "07:46", isNew: true),
                NoticeTimetableRow(departure: "07:35", arrival: "08:01", isNew: false)
            ],
            note: "* 도로 사정에 따라 도착 시간이 지연될 수 있습니다.",
            fullScheduleImageURL: nil
        )
    )

    NoticeDetailView(notice: sample)
        .preferredColorScheme(.dark)
}
