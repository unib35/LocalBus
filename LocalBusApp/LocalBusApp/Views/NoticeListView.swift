import SwiftUI

// MARK: - 공지사항 목록 뷰

struct NoticeListView: View {
    let notices: [NoticeItem]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(notices.enumerated()), id: \.element.id) { index, notice in
                        NavigationLink(destination: NoticeDetailView(notice: notice)) {
                            noticeRow(notice)
                        }
                        .buttonStyle(.plain)

                        if index < notices.count - 1 {
                            rowDivider
                        }
                    }
                }
                .background(Color(red: 28/255, green: 28/255, blue: 30/255))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("공지사항")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black.opacity(0.95), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Notice Row

    private func noticeRow(_ notice: NoticeItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(notice.title)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if notice.isNew {
                        newBadge
                    }
                }

                Text(notice.date)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 142/255, green: 142/255, blue: 147/255))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 99/255, green: 99/255, blue: 102/255))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var newBadge: some View {
        Text("NEW")
            .font(.system(size: 10, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(.black)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(.white)
            .clipShape(Capsule())
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color(red: 56/255, green: 56/255, blue: 58/255))
            .frame(height: 0.5)
            .padding(.leading, 16)
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
                    body: ["시간표가 변경됩니다."],
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
