import SwiftUI

// MARK: - 이용 안내 항목 모델

private struct TipItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
}

private struct TipSection: Identifiable {
    let id = UUID()
    let header: String
    let items: [TipItem]
}

// MARK: - 이용 안내 화면 (디자인 캔버스 개선안)
//
// 처음 타는 사람이 꼭 알아야 할 3가지를 맨 위 강조 그룹으로. 나머지는 아이콘 없는 평면 리스트.
// 섹션은 캔버스대로 탑승 방법 · 차내 규정 · 이용 팁. 위젯 추가 방법은 구매 완료 화면의 안내를 다시 볼 곳이라 맨 끝에 둔다.

struct BusTipsView: View {
    @State private var quickReport: QuickReportContext?

    private let essentials: [TipItem] = [
        TipItem(
            title: "하차벨이 없어요",
            description: "내릴 정류장 전에 기사님께 말씀해 주세요"
        ),
        TipItem(
            title: "시간표는 갑을장유병원 출발 기준",
            description: "다음 정류장은 약 1분 뒤"
        ),
        TipItem(
            title: "심야버스는 전용 승차장",
            description: "일반 20번홈이 아니에요"
        )
    ]

    private let sections: [TipSection] = [
        TipSection(header: "탑승 방법", items: [
            TipItem(
                title: "교통카드 사용 가능",
                description: "승·하차 시 교통카드 태그를 권장합니다. 미리 준비해 주세요."
            ),
            TipItem(
                title: "만석 시 탑승 불가",
                description: "좌석이 모두 차면 다음 버스를 이용해 주세요."
            ),
            TipItem(
                title: "줄서기",
                description: "승차 대기 시 인도를 방해하지 않도록 일렬로 줄을 서주세요."
            )
        ]),
        TipSection(header: "차내 규정", items: [
            TipItem(
                title: "음식물 섭취 금지",
                description: "차 안에서의 음식물 섭취는 금지되어 있습니다."
            ),
            TipItem(
                title: "쏟아질 수 있는 음료 반입 금지",
                description: "뚜껑이 없는 컵이나 흘릴 위험이 있는 음료는 가져오실 수 없습니다."
            ),
            TipItem(
                title: "큰 짐은 트렁크에",
                description: "대형 짐은 버스 트렁크에 보관해 주세요. 통로를 막지 않도록 협조 부탁드립니다."
            )
        ]),
        TipSection(header: "이용 팁", items: [
            TipItem(
                title: "출퇴근·등교 시간대",
                description: "오전 7~8시 혼잡 시간대에는 앞쪽 정류장에서 탑승하시면 좌석 확보에 유리합니다."
            )
        ]),
        TipSection(header: "위젯 추가", items: [
            TipItem(
                title: "홈 화면",
                description: "홈 화면 빈 곳을 길게 누르고 → 왼쪽 위 편집(또는 +)에서 위젯 추가 → 장유사상버스를 찾아 소형·중형·대형 중 선택."
            ),
            TipItem(
                title: "잠금 화면",
                description: "잠금 화면을 길게 누르고 → 사용자화 › 잠금 화면 → 시계 아래 위젯 영역에서 장유사상버스를 찾아 사각형·원형 중 선택."
            ),
            TipItem(
                title: "노선·방향 바꾸기",
                description: "위젯을 길게 눌러 '위젯 편집'에서 노선과 방향을 바꿀 수 있어요."
            )
        ])
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                Text("버스 이용 안내")
                    .font(AppTheme.Typography.screenTitle)
                    .foregroundStyle(AppTheme.Color.primaryText)
                    .padding(.top, 8)

                essentialsGroup

                ForEach(sections) { section in
                    tipSection(section)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(AmbientBackground())
        .softScrollEdge()
        .navigationBarTitleDisplayMode(.inline)
        .legacyToolbarBackground(AppTheme.Color.screenBackground.opacity(0.95))
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditReportLink(accessibilityLabel: "이용 안내 수정 제보") {
                    quickReport = QuickReportContext(entry: .guide, info: nil)
                }
            }
        }
        .sheet(item: $quickReport) { context in
            QuickReportView(context: context)
        }
    }

    // MARK: - 처음 타신다면

    private var essentialsGroup: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("처음 타신다면")
                .font(AppTheme.Typography.caption.weight(.bold))
                .tracking(0.3)
                .foregroundStyle(AppTheme.Color.secondaryText)
                .padding(.horizontal, 18)
                .padding(.top, 18)

            VStack(spacing: 0) {
                ForEach(Array(essentials.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: 14) {
                        Text("\(index + 1)")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppTheme.Color.accent)
                            .frame(width: 28, alignment: .leading)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppTheme.Color.primaryText)
                            Text(item.description)
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.Color.secondaryText)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .accessibilityElement(children: .combine)

                    if index < essentials.count - 1 {
                        RowDivider(leadingInset: 18)
                            .padding(.trailing, 18)
                    }
                }
            }
        }
        .surfaceCard()
    }

    // MARK: - 섹션 뷰

    private func tipSection(_ section: TipSection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(section.header)
                .font(AppTheme.Typography.groupTitle)
                .foregroundStyle(AppTheme.Color.primaryText)
                .padding(.bottom, 6)

            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.Color.primaryText)
                    Text(item.description)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.Color.secondaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)

                if index < section.items.count - 1 {
                    RowDivider(leadingInset: 0)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BusTipsView()
    }
    .preferredColorScheme(.dark)
}
