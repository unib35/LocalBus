import SwiftUI

// MARK: - 이용 안내 항목 모델

private struct TipItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

private struct TipSection: Identifiable {
    let id = UUID()
    let header: String
    let items: [TipItem]
}

// MARK: - 이용 안내 화면

struct BusTipsView: View {
    private let sections: [TipSection] = [
        TipSection(header: "탑승 방법", items: [
            TipItem(
                icon: "creditcard",
                title: "교통카드 사용 가능",
                description: "승·하차 시 교통카드 태그를 권장합니다. 카드를 이용하신다면 미리 준비해 주세요."
            ),
            TipItem(
                icon: "person.3",
                title: "만석 시 탑승 불가",
                description: "좌석이 모두 찬 경우 탑승이 불가합니다. 다음 버스를 이용해 주세요."
            ),
            TipItem(
                icon: "hand.raised",
                title: "하차 의사 표현 필수",
                description: "하차벨이 없으므로 내리실 정류장 전에 기사님께 직접 말씀해 주세요."
            ),
            TipItem(
                icon: "figure.stand.line.dotted.figure.stand",
                title: "줄서기",
                description: "승차 대기 시 인도를 방해하지 않도록 일렬로 줄을 서주세요."
            )
        ]),
        TipSection(header: "차내 규정", items: [
            TipItem(
                icon: "fork.knife",
                title: "음식물 섭취 금지",
                description: "차 안에서의 음식물 섭취는 금지되어 있습니다."
            ),
            TipItem(
                icon: "cup.and.saucer",
                title: "쏟아질 수 있는 음료 반입 금지",
                description: "뚜껑이 없는 컵이나 흘릴 위험이 있는 음료는 가져오실 수 없습니다."
            ),
            TipItem(
                icon: "suitcase",
                title: "큰 짐은 트렁크에",
                description: "대형 짐은 버스 트렁크에 보관해 주세요. 통로를 막지 않도록 협조 부탁드립니다."
            )
        ]),
        TipSection(header: "시간표 안내", items: [
            TipItem(
                icon: "clock",
                title: "갑을장유병원 출발 기준",
                description: "시간표는 갑을장유병원 정류장 출발 기준입니다. 이후 정류장은 약 1분 뒤 도착합니다."
            ),
            TipItem(
                icon: "moon.stars",
                title: "심야버스 전용 승차장",
                description: "심야버스는 일반 20번홈이 아닌 심야버스 전용 승차장에서 탑승하세요."
            ),
            TipItem(
                icon: "exclamationmark.triangle",
                title: "도착 시간 지연 가능",
                description: "도로 사정에 따라 실제 도착 시간이 다소 지연될 수 있습니다."
            ),
            TipItem(
                icon: "calendar",
                title: "평일·주말 시간표 상이",
                description: "평일과 주말(공휴일 포함)의 운행 시간표가 다릅니다. 탑승 전 시간표를 꼭 확인해 주세요."
            )
        ]),
        TipSection(header: "이용 팁", items: [
            TipItem(
                icon: "sun.max",
                title: "출퇴근·등교 시간대",
                description: "오전 7~8시 혼잡 시간대에는 앞쪽 정류장에서 탑승하시면 좌석 확보에 유리합니다."
            )
        ])
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                ForEach(sections) { section in
                    tipSection(section)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .background(HomeDashboardTheme.screenBackground.ignoresSafeArea())
        .navigationTitle("이용 안내")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(HomeDashboardTheme.screenBackground.opacity(0.95), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - 섹션 뷰

    private func tipSection(_ section: TipSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.header)
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(HomeDashboardTheme.secondaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Rectangle()
                            .fill(HomeDashboardTheme.border)
                            .frame(height: 0.5)
                            .padding(.leading, 56)
                    }
                    tipRow(item)
                }
            }
            .background(HomeDashboardTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(HomeDashboardTheme.border, lineWidth: 0.5)
            )
        }
    }

    // MARK: - 항목 행

    private func tipRow(_ item: TipItem) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(HomeDashboardTheme.secondaryText)
                .frame(width: 28, height: 28)
                .background(HomeDashboardTheme.iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Text(item.description)
                    .font(.system(size: 13))
                    .foregroundStyle(HomeDashboardTheme.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BusTipsView()
    }
    .preferredColorScheme(.dark)
}
