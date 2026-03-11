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

    init(
        id: String, title: String, date: String, author: String,
        isNew: Bool = false, body: [String],
        timetableSummary: NoticeTimetableSummary? = nil
    ) {
        self.id = id; self.title = title; self.date = date
        self.author = author; self.isNew = isNew
        self.body = body; self.timetableSummary = timetableSummary
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

// MARK: - 공지사항 상세 뷰

struct NoticeDetailView: View {
    let notice: NoticeItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottom) {
            HomeDashboardTheme.screenBackground.ignoresSafeArea()


            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        titleSection
                        separator
                            .padding(.bottom, 32)
                        bodySection
                        if let summary = notice.timetableSummary {
                            timetableCard(summary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 96)
                }
            }

            footerButton
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("공지사항")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .frame(height: 60)
        .padding(.horizontal, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(HomeDashboardTheme.border)
                .frame(height: 1)
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(notice.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .lineSpacing(5)

            HStack(spacing: 8) {
                Text(notice.date)
                    .font(.system(size: 14))
                    .foregroundStyle(HomeDashboardTheme.secondaryText)

                Rectangle()
                    .fill(HomeDashboardTheme.border)
                    .frame(width: 1, height: 12)

                Text(notice.author)
                    .font(.system(size: 14))
                    .foregroundStyle(HomeDashboardTheme.secondaryText)
            }
            .padding(.top, 4)
        }
        .padding(.bottom, 24)
    }

    private var separator: some View {
        Rectangle()
            .fill(HomeDashboardTheme.border)
            .frame(height: 1)
    }

    // MARK: - Body

    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(notice.body.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.system(size: 16))
                    .foregroundStyle(Color(red: 209/255, green: 213/255, blue: 219/255))
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.bottom, 32)
    }

    // MARK: - Timetable Card

    private func timetableCard(_ summary: NoticeTimetableSummary) -> some View {
        VStack(spacing: 16) {
            cardHeader(summary)
            scheduleTable(summary)
            if let url = summary.fullScheduleImageURL {
                fullScheduleImage(url: url)
            }
        }
        .padding(17)
        .background(HomeDashboardTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HomeDashboardTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .padding(.bottom, 24)
    }

    private func cardHeader(_ summary: NoticeTimetableSummary) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(HomeDashboardTheme.secondaryText)
                Text("변경 시간표 요약")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            Spacer()

            Text("\(summary.effectiveDate) 시행")
                .font(.system(size: 12))
                .foregroundStyle(HomeDashboardTheme.secondaryText)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(HomeDashboardTheme.screenBackground)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(HomeDashboardTheme.border, lineWidth: 1)
                )
        }
    }

    private func scheduleTable(_ summary: NoticeTimetableSummary) -> some View {
        VStack(spacing: 0) {
            // Column headers
            HStack(spacing: 0) {
                Text(summary.departureLabel)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(HomeDashboardTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                Text(summary.arrivalLabel)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(HomeDashboardTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .background(Color.white.opacity(0.03))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(HomeDashboardTheme.border)
                    .frame(height: 1)
            }

            // Data rows
            ForEach(summary.rows) { row in
                scheduleRow(row)
            }

            // Note footer
            if let note = summary.note {
                Text(note)
                    .font(.system(size: 12))
                    .foregroundStyle(HomeDashboardTheme.tertiaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.02))
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(HomeDashboardTheme.border)
                            .frame(height: 1)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HomeDashboardTheme.border, lineWidth: 1)
        )
    }

    private func scheduleRow(_ row: NoticeTimetableRow) -> some View {
        let accentBlue = Color(red: 96/255, green: 165/255, blue: 250/255)
        let highlightBg = Color(red: 37/255, green: 99/255, blue: 235/255).opacity(0.08)

        return HStack(spacing: 0) {
            // Departure (with optional new-time indicator)
            ZStack {
                Text(row.departure)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(row.isNew ? accentBlue : .white)

                if row.isNew {
                    Circle()
                        .fill(Color(red: 239/255, green: 68/255, blue: 68/255))
                        .frame(width: 6, height: 6)
                        .offset(x: 22, y: -8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)

            // Arrival
            Text(row.arrival)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(HomeDashboardTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .background(row.isNew ? highlightBg : Color.clear)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(HomeDashboardTheme.border.opacity(0.6))
                .frame(height: 1)
        }
    }

    // MARK: - Full Schedule Image

    private func fullScheduleImage(url: URL) -> some View {
        KFImage(url)
            .placeholder {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(HomeDashboardTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(HomeDashboardTheme.border, lineWidth: 1)
                        )
                    ProgressView()
                        .tint(.white)
                }
                .frame(height: 200)
            }
            .fade(duration: 0.3)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(HomeDashboardTheme.border, lineWidth: 1)
            )
    }

    // MARK: - Footer

    private var footerButton: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(HomeDashboardTheme.border)
                .frame(height: 1)

            Button(action: { dismiss() }) {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 14, weight: .medium))
                    Text("목록으로")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .white.opacity(0.06), radius: 16)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 17)
            .padding(.bottom, 16)
        }
        .background(HomeDashboardTheme.screenBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(HomeDashboardTheme.border)
                .frame(height: 1)
        }
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
