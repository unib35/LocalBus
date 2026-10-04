import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.2, *)
struct BusLiveActivityView: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusLiveActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.direction).font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.isStale ? "예정 시간 경과" : "예약한 버스").font(.caption)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    scheduledTimes(context)
                }
            } compactLeading: {
                Image(systemName: "bus.fill")
            } compactTrailing: {
                Text(context.attributes.departureTime).font(.caption.monospacedDigit())
                    .accessibilityLabel("예약한 버스 " + context.attributes.departureTime + " 출발 예정")
            } minimal: {
                Image(systemName: "bus.fill")
            }
        }
    }
}

@available(iOS 16.2, *)
private func scheduledTimes(_ context: ActivityViewContext<BusLiveActivityAttributes>) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text("출발 예정 " + scheduledDate(context.state.departureDate))
        Text("도착 예상 " + scheduledDate(context.state.arrivalDate))
        Text("시간표 기준 · 실제 운행 상황과 다를 수 있습니다")
            .font(.caption2).foregroundStyle(.secondary)
    }
    .font(.subheadline.monospacedDigit())
}

private func scheduledDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
    formatter.dateFormat = "M/d HH:mm"
    return formatter.string(from: date)
}

@available(iOS 16.2, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<BusLiveActivityAttributes>
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(context.attributes.direction).font(.headline)
            Text(context.isStale ? "예정 시간 경과" : "예약한 버스").font(.caption)
            scheduledTimes(context)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .activityBackgroundTint(Color.black)
        .foregroundStyle(.white)
    }
}

#Preview("잠금화면", as: .content, using: BusLiveActivityAttributes(
    direction: "장유 → 사상", departureTime: "07:20", durationMinutes: 40
)) {
    BusLiveActivityView()
} contentStates: {
    BusLiveActivityAttributes.ContentState(departureDate: .now.addingTimeInterval(600),
        arrivalDate: .now.addingTimeInterval(3000), phase: .waitingForDeparture)
    BusLiveActivityAttributes.ContentState(departureDate: .now.addingTimeInterval(-600),
        arrivalDate: .now.addingTimeInterval(1800), phase: .inTransit)
}

#Preview("Dynamic Island · 펼침", as: .dynamicIsland(.expanded), using: BusLiveActivityAttributes(
    direction: "장유 → 사상", departureTime: "07:20", durationMinutes: 40
)) {
    BusLiveActivityView()
} contentStates: {
    BusLiveActivityAttributes.ContentState(departureDate: .now.addingTimeInterval(600),
        arrivalDate: .now.addingTimeInterval(3000), phase: .waitingForDeparture)
    BusLiveActivityAttributes.ContentState(departureDate: .now.addingTimeInterval(-600),
        arrivalDate: .now.addingTimeInterval(1800), phase: .inTransit)
}

#Preview("Dynamic Island · 축소", as: .dynamicIsland(.compact), using: BusLiveActivityAttributes(
    direction: "장유 → 사상", departureTime: "07:20", durationMinutes: 40
)) {
    BusLiveActivityView()
} contentStates: {
    BusLiveActivityAttributes.ContentState(departureDate: .now.addingTimeInterval(600),
        arrivalDate: .now.addingTimeInterval(3000), phase: .waitingForDeparture)
    BusLiveActivityAttributes.ContentState(departureDate: .now.addingTimeInterval(-600),
        arrivalDate: .now.addingTimeInterval(1800), phase: .inTransit)
}

#Preview("Dynamic Island · 최소", as: .dynamicIsland(.minimal), using: BusLiveActivityAttributes(
    direction: "장유 → 사상", departureTime: "07:20", durationMinutes: 40
)) {
    BusLiveActivityView()
} contentStates: {
    BusLiveActivityAttributes.ContentState(departureDate: .now.addingTimeInterval(600),
        arrivalDate: .now.addingTimeInterval(3000), phase: .waitingForDeparture)
    BusLiveActivityAttributes.ContentState(departureDate: .now.addingTimeInterval(-600),
        arrivalDate: .now.addingTimeInterval(1800), phase: .inTransit)
}
