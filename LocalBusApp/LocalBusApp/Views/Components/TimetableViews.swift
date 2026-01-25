import SwiftUI

// MARK: - 시간표 타입 선택

/// 평일/주말 시간표 선택 피커
struct ScheduleTypePicker: View {
    @Binding var selection: ScheduleType

    var body: some View {
        Picker("시간표", selection: $selection) {
            ForEach(ScheduleType.allCases, id: \.self) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
    }
}

// MARK: - 시간표 리스트

/// 시간표 세로 리스트 뷰
struct TimetableGrid: View {
    let times: [String]
    let nextBusTime: String?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(times.enumerated()), id: \.element) { index, time in
                TimeRow(
                    time: time,
                    isNextBus: time == nextBusTime,
                    isPast: isPastTime(time)
                )

                if index < times.count - 1 {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func isPastTime(_ time: String) -> Bool {
        guard let nextTime = nextBusTime,
              let nextIndex = times.firstIndex(of: nextTime),
              let timeIndex = times.firstIndex(of: time) else {
            return nextBusTime == nil
        }
        return timeIndex < nextIndex
    }
}

// MARK: - 시간 행

/// 개별 시간 표시 행
struct TimeRow: View {
    let time: String
    let isNextBus: Bool
    let isPast: Bool

    var body: some View {
        HStack {
            // 시간 표시
            Text(time)
                .font(.title3.monospacedDigit())
                .fontWeight(isNextBus ? .bold : .medium)
                .foregroundStyle(textColor)

            Spacer()

            // 다음 버스 표시
            if isNextBus {
                HStack(spacing: 6) {
                    Image(systemName: "bus.fill")
                        .font(.caption)
                    Text("다음 버스")
                        .font(.caption.bold())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(isNextBus ? Color.blue.opacity(0.1) : Color.clear)
    }

    private var textColor: Color {
        if isNextBus {
            return .blue
        } else if isPast {
            return Color(uiColor: .tertiaryLabel)
        }
        return .primary
    }
}

// MARK: - Preview

#Preview("ScheduleTypePicker") {
    struct PreviewWrapper: View {
        @State private var selection: ScheduleType = .weekday
        var body: some View {
            ScheduleTypePicker(selection: $selection)
                .padding()
        }
    }
    return PreviewWrapper()
}

#Preview("TimetableGrid") {
    TimetableGrid(
        times: ["06:00", "06:30", "07:00", "07:30", "08:00"],
        nextBusTime: "07:00"
    )
    .padding()
}
