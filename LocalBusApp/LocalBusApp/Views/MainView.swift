import SwiftUI

/// 메인 화면
struct MainView: View {
    @StateObject private var viewModel = MainViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 공지 배너
                if viewModel.hasNotice {
                    NoticeBanner(message: viewModel.noticeMessage ?? "")
                }

                // 평일/주말 탭
                ScheduleTypePicker(selection: $viewModel.selectedScheduleType)
                    .padding()

                // 시간표 리스트
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("시간표 로딩 중...")
                    Spacer()
                } else if viewModel.isServiceEnded {
                    Spacer()
                    EndOfServiceView()
                    Spacer()
                } else {
                    TimetableList(
                        times: viewModel.currentTimes,
                        nextBusTime: viewModel.nextBusTime
                    )
                }
            }
            .navigationTitle("장유 → 사상")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await viewModel.onAppear()
        }
    }
}

// MARK: - 공지 배너

struct NoticeBanner: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "megaphone.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .lineLimit(2)
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    }
}

// MARK: - 시간표 타입 선택

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

struct TimetableList: View {
    let times: [String]
    let nextBusTime: String?

    var body: some View {
        ScrollViewReader { proxy in
            List(times, id: \.self) { time in
                BusTimeCell(
                    time: time,
                    isNextBus: time == nextBusTime
                )
                .id(time)
            }
            .listStyle(.plain)
            .onAppear {
                // 다음 버스로 자동 스크롤
                if let nextBus = nextBusTime {
                    withAnimation {
                        proxy.scrollTo(nextBus, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - 버스 시간 셀

struct BusTimeCell: View {
    let time: String
    let isNextBus: Bool

    var body: some View {
        HStack {
            if isNextBus {
                Image(systemName: "bus.fill")
                    .foregroundStyle(.blue)
            }

            Text(time)
                .font(isNextBus ? .title2.bold() : .body)
                .foregroundStyle(isNextBus ? .blue : .primary)

            Spacer()

            if isNextBus {
                Text("다음 버스")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, isNextBus ? 8 : 4)
        .background(isNextBus ? Color.blue.opacity(0.1) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - 운행 종료 안내

struct EndOfServiceView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("오늘 운행이 종료되었습니다")
                .font(.title3)
                .fontWeight(.medium)

            Text("내일 첫차는 06:00 입니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    MainView()
}
