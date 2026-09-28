import SwiftUI

// MARK: - Pro 구매 완료 · 위젯 추가 안내 (디자인 캔버스 개선안 2)
//
// 결제만 하고 위젯을 못 넣는 경우를 막기 위해 홈 화면·잠금 화면 3단계를 바로 보여준다.

struct WidgetGuideStep: Identifiable {
    let title: String
    let body: String
    var id: String { title }
}

enum WidgetGuide {
    enum Place: String, CaseIterable, Identifiable {
        case home = "홈 화면"
        case lock = "잠금 화면"
        var id: String { rawValue }
    }

    static func steps(for place: Place) -> [WidgetGuideStep] {
        switch place {
        case .home:
            return [
                WidgetGuideStep(title: "홈 화면 빈 곳을 길게 눌러요", body: "아이콘이 흔들리기 시작하면 돼요"),
                WidgetGuideStep(title: "왼쪽 위 편집에서 위젯 추가", body: "기기에 따라 + 버튼으로 보여요"),
                WidgetGuideStep(title: "장유사상버스를 찾아 크기 선택", body: "소형·중형·대형 중에 골라 추가"),
            ]
        case .lock:
            return [
                WidgetGuideStep(title: "잠금 화면을 길게 눌러요", body: "아래에 사용자화 버튼이 나와요"),
                WidgetGuideStep(title: "사용자화 › 잠금 화면 선택", body: "시계 아래 위젯 추가 영역을 눌러요"),
                WidgetGuideStep(title: "장유사상버스를 찾아 추가", body: "사각형·원형 중에 골라요"),
            ]
        }
    }
}

struct PaywallSuccessView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var place: WidgetGuide.Place = .home

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.Color.primaryText)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(AppTheme.Color.surfaceSecondary))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("닫기")
                }
                .frame(height: 44)
                .padding(.trailing, -8)

                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(AppTheme.Color.accent)
                    Text("Pro를 시작했어요")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(AppTheme.Color.primaryText)
                    Text("이제 위젯만 추가하면 돼요. 1분이면 끝나요.")
                        .font(AppTheme.Typography.rowValue)
                        .foregroundStyle(AppTheme.Color.secondaryText)
                }
                .padding(.top, 12)
                .accessibilityElement(children: .combine)

                PillSegment(
                    items: WidgetGuide.Place.allCases,
                    selected: place,
                    label: { $0.rawValue },
                    onSelect: { selected in withAnimation(.easeInOut(duration: 0.15)) { place = selected } }
                )
                .padding(.top, 24)

                WidgetGuideStepsCard(steps: WidgetGuide.steps(for: place))
                    .padding(.top, 12)

                Text("위젯을 길게 눌러 '위젯 편집'에서 노선과 방향을 바꿀 수 있어요.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .padding(.horizontal, 4)
                    .padding(.top, 12)

                Spacer(minLength: 16)

                Button("확인") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle(height: 52))

                Text("이 안내는 설정 › 버스 이용 안내에서 다시 볼 수 있어요")
                    .font(AppTheme.Typography.footnote)
                    .foregroundStyle(AppTheme.Color.tertiaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 20)
        }
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(false)
    }
}

/// 번호 3개짜리 단계 카드. 결제 완료 화면과 이용 안내에서 같이 쓴다.
struct WidgetGuideStepsCard: View {
    let steps: [WidgetGuideStep]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 14) {
                    Text("\(index + 1)")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppTheme.Color.accent)
                        .frame(width: 28, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(step.title)
                            .font(AppTheme.Typography.rowBody.weight(.semibold))
                            .foregroundStyle(AppTheme.Color.primaryText)
                        Text(step.body)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Color.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 14)
                .accessibilityElement(children: .combine)

                if index < steps.count - 1 {
                    RowDivider(leadingInset: 0)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .surfaceCard()
    }
}

#Preview {
    PaywallSuccessView()
        .preferredColorScheme(.dark)
}
