//
//  RouteConfigIntent.swift
//  LocalBusWidget
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Route Option

enum WidgetRouteOption: String, AppEnum {
    case jangyuToSasang = "jangyu_to_sasang"
    case sasangToJangyu = "sasang_to_jangyu"
    case yulhaToSasang  = "yulha_to_sasang"
    case sasangToYulha  = "sasang_to_yulha"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "노선")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .jangyuToSasang: "장유 → 사상",
        .sasangToJangyu: "사상 → 장유",
        .yulhaToSasang:  "율하 → 사상",
        .sasangToYulha:  "사상 → 율하"
    ]

    var displayName: String {
        switch self {
        case .jangyuToSasang: "장유 → 사상"
        case .sasangToJangyu: "사상 → 장유"
        case .yulhaToSasang:  "율하 → 사상"
        case .sasangToYulha:  "사상 → 율하"
        }
    }
}

// MARK: - Configuration Intents
//
// 보기(캔버스 후보)는 위젯 추가 화면에서 위젯을 골라 정한다. 편집에서는 노선만 고른다.

/// 노선 선택. 출시된 위젯이 쓰는 intent라 이름과 파라미터를 바꾸지 않는다.
struct RouteConfigIntent: AppIntent, WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "노선 선택"
    static var description = IntentDescription("표시할 버스 노선을 선택합니다")

    @Parameter(title: "노선", default: .jangyuToSasang)
    var route: WidgetRouteOption

    init() {}
    init(route: WidgetRouteOption) { self.route = route }
}

/// 도착 목표 위젯: 노선과 도착하고 싶은 시각
struct TargetRouteConfigIntent: AppIntent, WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "노선과 도착 시각"
    static var description = IntentDescription("노선과 도착하고 싶은 시각을 정합니다")

    @Parameter(title: "노선", default: .jangyuToSasang)
    var route: WidgetRouteOption

    @Parameter(title: "도착 목표 시각", default: "08:30")
    var targetTime: String

    init() {}
}

/// "8:30", "0830", "08시30분" 같은 입력을 "HH:mm"으로 맞춘다. 못 읽으면 기본값.
enum WidgetTimeInput {
    static func normalize(_ raw: String, fallback: String = "08:30") -> String {
        let numbers = raw.filter(\.isNumber)
        guard numbers.count >= 3, numbers.count <= 4,
              let value = Int(numbers) else { return fallback }
        let hour = value / 100
        let minute = value % 100
        guard (0...23).contains(hour), (0...59).contains(minute) else { return fallback }
        return String(format: "%02d:%02d", hour, minute)
    }
}

// MARK: - Providers

private func makeTimeline(routeKey: String, direction: String, options: WidgetOptions) -> Timeline<BusEntry> {
    let currentDate = Date()
    var entries: [BusEntry] = []
    for minuteOffset in 0..<30 {
        let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
        entries.append(WidgetDataHelper.createEntry(for: entryDate, routeKey: routeKey, direction: direction, options: options))
    }
    let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate)!
    return Timeline(entries: entries, policy: .after(nextUpdate))
}

/// 위젯 추가 화면의 미리보기는 예시 값으로 그린다. 실제 값으로 그리면 밤에는 모든 후보가 '운행 종료'로 똑같이 보인다.
private func previewEntry(route: WidgetRouteOption, options: WidgetOptions) -> BusEntry {
    BusEntry.placeholder(options: options, routeKey: route.rawValue, direction: route.displayName)
}

struct ConfigurableProvider: AppIntentTimelineProvider {
    typealias Entry = BusEntry
    typealias Intent = RouteConfigIntent

    /// 이 위젯이 보여 줄 보기 (크기마다 하나)
    var options: WidgetOptions = .default

    func placeholder(in context: Context) -> BusEntry { BusEntry.placeholder(options: options) }

    func snapshot(for configuration: RouteConfigIntent, in context: Context) async -> BusEntry {
        if context.isPreview { return previewEntry(route: configuration.route, options: options) }
        return WidgetDataHelper.createEntry(for: Date(), routeKey: configuration.route.rawValue, direction: configuration.route.displayName, options: options)
    }

    func timeline(for configuration: RouteConfigIntent, in context: Context) async -> Timeline<BusEntry> {
        makeTimeline(routeKey: configuration.route.rawValue, direction: configuration.route.displayName, options: options)
    }
}

struct TargetProvider: AppIntentTimelineProvider {
    typealias Entry = BusEntry
    typealias Intent = TargetRouteConfigIntent

    private func options(for configuration: TargetRouteConfigIntent) -> WidgetOptions {
        WidgetOptions(small: .target, medium: .target, targetTime: WidgetTimeInput.normalize(configuration.targetTime))
    }

    func placeholder(in context: Context) -> BusEntry {
        BusEntry.placeholder(options: WidgetOptions(small: .target, medium: .target))
    }

    func snapshot(for configuration: TargetRouteConfigIntent, in context: Context) async -> BusEntry {
        let options = options(for: configuration)
        if context.isPreview { return previewEntry(route: configuration.route, options: options) }
        return WidgetDataHelper.createEntry(for: Date(), routeKey: configuration.route.rawValue, direction: configuration.route.displayName, options: options)
    }

    func timeline(for configuration: TargetRouteConfigIntent, in context: Context) async -> Timeline<BusEntry> {
        makeTimeline(routeKey: configuration.route.rawValue, direction: configuration.route.displayName, options: options(for: configuration))
    }
}

// MARK: - Widgets (캔버스 후보마다 위젯 추가 화면에 하나씩)
//
// 같은 생각의 후보는 크기만 다른 한 위젯으로 묶는다. 위젯 추가 화면에서 위젯을 고르고 옆으로 넘겨 크기를 고른다.
//
//  위젯            소형   중형   대형   잠금 화면
//  다음 버스        A      A      A     사각형 · 원형(남은 시간) · 한 줄
//  출발 → 도착      B      B            원형(출발 시각)
//  다음 3대         C
//  막차            D
//  양방향          E      C
//  도착 목표        F      F
//  세로 타임라인     G
//  시간표                 D      B
//  하루 요약               E

private func routeWidget(
    kind: String,
    name: String,
    description: String,
    families: [WidgetFamily],
    options: WidgetOptions
) -> some WidgetConfiguration {
    AppIntentConfiguration(kind: kind, intent: RouteConfigIntent.self, provider: ConfigurableProvider(options: options)) { entry in
        LocalBusWidgetEntryView(entry: entry)
            .containerBackground(for: .widget) { WidgetContainerBackground() }
    }
    .configurationDisplayName(name)
    .description(description)
    .supportedFamilies(families)
    .contentMarginsDisabled()
}

/// 남은 시간. 출시된 위젯이라 kind와 지원 크기를 그대로 둔다.
struct LocalBusConfigurableWidget: Widget {
    let kind: String = "LocalBusConfigurableWidget"

    var body: some WidgetConfiguration {
        routeWidget(
            kind: kind,
            name: "다음 버스",
            description: "남은 시간을 크게. 중형은 이후 3대, 대형은 이어지는 버스 표까지",
            families: [.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline],
            options: .default
        )
    }
}

struct LocalBusArrivalWidget: Widget {
    let kind: String = "LocalBusArrivalWidget"

    var body: some WidgetConfiguration {
        routeWidget(
            kind: kind,
            name: "출발 → 도착",
            description: "출발 시각과 도착 예상을 함께. 잠금 화면 원형은 출발 시각만",
            families: [.systemSmall, .systemMedium, .accessoryCircular],
            options: WidgetOptions(small: .arrival, medium: .arrival, circular: .departure)
        )
    }
}

struct LocalBusNextThreeWidget: Widget {
    let kind: String = "LocalBusNextThreeWidget"

    var body: some WidgetConfiguration {
        routeWidget(
            kind: kind,
            name: "다음 3대",
            description: "한 대를 놓쳐도 바로 다음 버스가 보여요",
            families: [.systemSmall],
            options: WidgetOptions(small: .list)
        )
    }
}

struct LocalBusLastBusWidget: Widget {
    let kind: String = "LocalBusLastBusWidget"

    var body: some WidgetConfiguration {
        routeWidget(
            kind: kind,
            name: "막차",
            description: "막차 시각과 남은 시간, 심야 요금",
            families: [.systemSmall],
            options: WidgetOptions(small: .lastBus)
        )
    }
}

struct LocalBusBothWaysWidget: Widget {
    let kind: String = "LocalBusBothWaysWidget"

    var body: some WidgetConfiguration {
        routeWidget(
            kind: kind,
            name: "양방향",
            description: "가는 버스와 오는 버스를 한 번에",
            families: [.systemSmall, .systemMedium],
            options: WidgetOptions(small: .bothWays, medium: .bothWays)
        )
    }
}

struct LocalBusTargetWidget: Widget {
    let kind: String = "LocalBusTargetWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: TargetRouteConfigIntent.self, provider: TargetProvider()) { entry in
            LocalBusWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { WidgetContainerBackground() }
        }
        .configurationDisplayName("도착 목표")
        .description("정한 시각까지 도착하려면 타야 할 버스. 위젯 편집에서 도착 시각을 정해요")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct LocalBusTimelineWidget: Widget {
    let kind: String = "LocalBusTimelineWidget"

    var body: some WidgetConfiguration {
        routeWidget(
            kind: kind,
            name: "세로 타임라인",
            description: "출발과 도착 예상을 위아래로",
            families: [.systemSmall],
            options: WidgetOptions(small: .timeline)
        )
    }
}

struct LocalBusTimetableWidget: Widget {
    let kind: String = "LocalBusTimetableWidget"

    var body: some WidgetConfiguration {
        routeWidget(
            kind: kind,
            name: "시간표",
            description: "중형은 지금과 다음 시간대, 대형은 오늘 시간표",
            families: [.systemMedium, .systemLarge],
            options: WidgetOptions(medium: .hourGrid, large: .grid)
        )
    }
}

struct LocalBusDaySummaryWidget: Widget {
    let kind: String = "LocalBusDaySummaryWidget"

    var body: some WidgetConfiguration {
        routeWidget(
            kind: kind,
            name: "하루 요약",
            description: "다음 버스와 막차 · 심야 요금 · 내일 첫차",
            families: [.systemMedium],
            options: WidgetOptions(medium: .summary)
        )
    }
}

/// 새로 더한 후보 위젯 묶음. 번들 한 곳에 넣을 수 있는 수를 넘지 않게 나눠 둔다.
struct CandidateWidgetBundle: WidgetBundle {
    var body: some Widget {
        LocalBusArrivalWidget()
        LocalBusNextThreeWidget()
        LocalBusLastBusWidget()
        LocalBusBothWaysWidget()
        LocalBusTargetWidget()
        LocalBusTimelineWidget()
        LocalBusTimetableWidget()
        LocalBusDaySummaryWidget()
    }
}
