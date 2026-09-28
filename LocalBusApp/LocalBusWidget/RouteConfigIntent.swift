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

// MARK: - Style Options (디자인 캔버스 위젯 후보 — 고르지 않고 모두 제공)

enum SmallStyleOption: String, AppEnum {
    case remaining, arrival, list, lastBus, bothWays, target, timeline

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "보기")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .remaining: "남은 시간",
        .arrival: "출발 → 도착",
        .list: "다음 3대",
        .lastBus: "막차",
        .bothWays: "양방향",
        .target: "도착 목표",
        .timeline: "세로 타임라인"
    ]

    var style: SmallWidgetStyle {
        switch self {
        case .remaining: .remaining
        case .arrival: .arrival
        case .list: .list
        case .lastBus: .lastBus
        case .bothWays: .bothWays
        case .target: .target
        case .timeline: .timeline
        }
    }
}

enum MediumStyleOption: String, AppEnum {
    case remaining, arrival, bothWays, hourGrid, summary, target

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "보기")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .remaining: "남은 시간 + 이후 3대",
        .arrival: "출발 → 도착 타임라인",
        .bothWays: "양방향",
        .hourGrid: "시간대 시간표",
        .summary: "다음 버스 + 하루 요약",
        .target: "도착 목표"
    ]

    var style: MediumWidgetStyle {
        switch self {
        case .remaining: .remaining
        case .arrival: .arrival
        case .bothWays: .bothWays
        case .hourGrid: .hourGrid
        case .summary: .summary
        case .target: .target
        }
    }
}

enum LargeStyleOption: String, AppEnum {
    case list, grid

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "보기")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .list: "다음 버스 + 이어지는 버스",
        .grid: "오늘 시간표"
    ]

    var style: LargeWidgetStyle {
        switch self {
        case .list: .list
        case .grid: .grid
        }
    }
}

enum CircularStyleOption: String, AppEnum {
    case remaining, departure

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "원형 보기")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .remaining: "남은 시간 고리",
        .departure: "출발 시각"
    ]

    var style: LockCircularStyle {
        switch self {
        case .remaining: .remaining
        case .departure: .departure
        }
    }
}

// MARK: - Configuration Intents (크기마다 하나)

/// 소형 위젯. 기존 설치를 깨지 않도록 kind와 intent 이름은 그대로 둔다.
struct RouteConfigIntent: AppIntent, WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "노선 선택"
    static var description = IntentDescription("표시할 버스 노선과 보기 방식을 선택합니다")

    @Parameter(title: "노선", default: .jangyuToSasang)
    var route: WidgetRouteOption

    @Parameter(title: "보기", default: .remaining)
    var style: SmallStyleOption

    @Parameter(title: "도착 목표 시각 (도착 목표 보기)", default: "08:30")
    var targetTime: String

    init() {}
    init(route: WidgetRouteOption, style: SmallStyleOption = .remaining, targetTime: String = "08:30") {
        self.route = route
        self.style = style
        self.targetTime = targetTime
    }

    var options: WidgetOptions {
        WidgetOptions(small: style.style, targetTime: WidgetTimeInput.normalize(targetTime))
    }
}

struct MediumRouteConfigIntent: AppIntent, WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "노선 선택"
    static var description = IntentDescription("표시할 버스 노선과 보기 방식을 선택합니다")

    @Parameter(title: "노선", default: .jangyuToSasang)
    var route: WidgetRouteOption

    @Parameter(title: "보기", default: .remaining)
    var style: MediumStyleOption

    @Parameter(title: "도착 목표 시각 (도착 목표 보기)", default: "08:30")
    var targetTime: String

    init() {}

    var options: WidgetOptions {
        WidgetOptions(medium: style.style, targetTime: WidgetTimeInput.normalize(targetTime))
    }
}

struct LargeRouteConfigIntent: AppIntent, WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "노선 선택"
    static var description = IntentDescription("표시할 버스 노선과 보기 방식을 선택합니다")

    @Parameter(title: "노선", default: .jangyuToSasang)
    var route: WidgetRouteOption

    @Parameter(title: "보기", default: .list)
    var style: LargeStyleOption

    init() {}

    var options: WidgetOptions {
        WidgetOptions(large: style.style)
    }
}

struct LockRouteConfigIntent: AppIntent, WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "노선 선택"
    static var description = IntentDescription("잠금 화면에 표시할 버스 노선을 선택합니다")

    @Parameter(title: "노선", default: .jangyuToSasang)
    var route: WidgetRouteOption

    @Parameter(title: "원형 보기", default: .remaining)
    var circular: CircularStyleOption

    init() {}

    var options: WidgetOptions {
        WidgetOptions(circular: circular.style)
    }
}

/// "8:30", "0830", "08시30분" 같은 입력을 "HH:mm"으로 맞춘다. 못 읽으면 기본값.
enum WidgetTimeInput {
    static func normalize(_ raw: String, fallback: String = "08:30") -> String {
        let digits = raw.filter(\.isNumber)
        guard digits.count >= 3, digits.count <= 4,
              let value = Int(digits) else { return fallback }
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

struct ConfigurableProvider: AppIntentTimelineProvider {
    typealias Entry = BusEntry
    typealias Intent = RouteConfigIntent

    func placeholder(in context: Context) -> BusEntry { BusEntry.placeholder() }

    func snapshot(for configuration: RouteConfigIntent, in context: Context) async -> BusEntry {
        WidgetDataHelper.createEntry(for: Date(), routeKey: configuration.route.rawValue, direction: configuration.route.displayName, options: configuration.options)
    }

    func timeline(for configuration: RouteConfigIntent, in context: Context) async -> Timeline<BusEntry> {
        makeTimeline(routeKey: configuration.route.rawValue, direction: configuration.route.displayName, options: configuration.options)
    }
}

struct MediumProvider: AppIntentTimelineProvider {
    typealias Entry = BusEntry
    typealias Intent = MediumRouteConfigIntent

    func placeholder(in context: Context) -> BusEntry { BusEntry.placeholder() }

    func snapshot(for configuration: MediumRouteConfigIntent, in context: Context) async -> BusEntry {
        WidgetDataHelper.createEntry(for: Date(), routeKey: configuration.route.rawValue, direction: configuration.route.displayName, options: configuration.options)
    }

    func timeline(for configuration: MediumRouteConfigIntent, in context: Context) async -> Timeline<BusEntry> {
        makeTimeline(routeKey: configuration.route.rawValue, direction: configuration.route.displayName, options: configuration.options)
    }
}

struct LargeProvider: AppIntentTimelineProvider {
    typealias Entry = BusEntry
    typealias Intent = LargeRouteConfigIntent

    func placeholder(in context: Context) -> BusEntry { BusEntry.placeholder(options: WidgetOptions(large: .list)) }

    func snapshot(for configuration: LargeRouteConfigIntent, in context: Context) async -> BusEntry {
        WidgetDataHelper.createEntry(for: Date(), routeKey: configuration.route.rawValue, direction: configuration.route.displayName, options: configuration.options)
    }

    func timeline(for configuration: LargeRouteConfigIntent, in context: Context) async -> Timeline<BusEntry> {
        makeTimeline(routeKey: configuration.route.rawValue, direction: configuration.route.displayName, options: configuration.options)
    }
}

struct LockProvider: AppIntentTimelineProvider {
    typealias Entry = BusEntry
    typealias Intent = LockRouteConfigIntent

    func placeholder(in context: Context) -> BusEntry { BusEntry.placeholder() }

    func snapshot(for configuration: LockRouteConfigIntent, in context: Context) async -> BusEntry {
        WidgetDataHelper.createEntry(for: Date(), routeKey: configuration.route.rawValue, direction: configuration.route.displayName, options: configuration.options)
    }

    func timeline(for configuration: LockRouteConfigIntent, in context: Context) async -> Timeline<BusEntry> {
        makeTimeline(routeKey: configuration.route.rawValue, direction: configuration.route.displayName, options: configuration.options)
    }
}

// MARK: - Widgets (크기별)

/// 소형. kind는 기존 설치 유지를 위해 그대로.
struct LocalBusConfigurableWidget: Widget {
    let kind: String = "LocalBusConfigurableWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: RouteConfigIntent.self, provider: ConfigurableProvider()) { entry in
            LocalBusWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { WidgetContainerBackground() }
        }
        .configurationDisplayName("다음 버스")
        .description("남은 시간 · 출발 → 도착 · 다음 3대 · 막차 · 양방향 · 도착 목표 · 세로 타임라인")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct LocalBusMediumWidget: Widget {
    let kind: String = "LocalBusMediumWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: MediumRouteConfigIntent.self, provider: MediumProvider()) { entry in
            LocalBusWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { WidgetContainerBackground() }
        }
        .configurationDisplayName("다음 버스 · 중형")
        .description("남은 시간 · 출발 → 도착 · 양방향 · 시간대 시간표 · 하루 요약 · 도착 목표")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct LocalBusLargeWidget: Widget {
    let kind: String = "LocalBusLargeWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: LargeRouteConfigIntent.self, provider: LargeProvider()) { entry in
            LocalBusWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { WidgetContainerBackground() }
        }
        .configurationDisplayName("다음 버스 · 대형")
        .description("이어지는 버스 표 또는 오늘 시간표 전체")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

struct LocalBusLockWidget: Widget {
    let kind: String = "LocalBusLockWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: LockRouteConfigIntent.self, provider: LockProvider()) { entry in
            LocalBusWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { WidgetContainerBackground() }
        }
        .configurationDisplayName("다음 버스 · 잠금 화면")
        .description("사각형 · 원형 · 한 줄")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
