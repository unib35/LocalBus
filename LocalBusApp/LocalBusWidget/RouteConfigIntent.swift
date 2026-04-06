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

// MARK: - Configuration Intent

struct RouteConfigIntent: AppIntent, WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "노선 선택"
    static var description = IntentDescription("표시할 버스 노선을 선택합니다")

    @Parameter(title: "노선", default: .jangyuToSasang)
    var route: WidgetRouteOption

    init() {}
    init(route: WidgetRouteOption) { self.route = route }
}

// MARK: - Configurable Provider

struct ConfigurableProvider: AppIntentTimelineProvider {
    typealias Entry = BusEntry
    typealias Intent = RouteConfigIntent

    func placeholder(in context: Context) -> BusEntry {
        BusEntry(
            date: Date(),
            routeKey: WidgetRouteOption.jangyuToSasang.rawValue,
            nextBusTime: "07:00",
            remainingMinutes: 15,
            direction: "장유 → 사상",
            isServiceEnded: false,
            firstBusTime: "06:00",
            upcomingBuses: [("07:20", 35), ("07:40", 55), ("08:00", 75), ("08:20", 95)],
            isLastBus: false,
            isNightBus: false
        )
    }

    func snapshot(for configuration: RouteConfigIntent, in context: Context) async -> BusEntry {
        WidgetDataHelper.createEntry(
            for: Date(),
            routeKey: configuration.route.rawValue,
            direction: configuration.route.displayName
        )
    }

    func timeline(for configuration: RouteConfigIntent, in context: Context) async -> Timeline<BusEntry> {
        let currentDate = Date()
        var entries: [BusEntry] = []

        for minuteOffset in 0..<30 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            entries.append(WidgetDataHelper.createEntry(
                for: entryDate,
                routeKey: configuration.route.rawValue,
                direction: configuration.route.displayName
            ))
        }

        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate)!
        return Timeline(entries: entries, policy: .after(nextUpdate))
    }
}

// MARK: - Configurable Widget

struct LocalBusConfigurableWidget: Widget {
    let kind: String = "LocalBusConfigurableWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: RouteConfigIntent.self,
            provider: ConfigurableProvider()
        ) { entry in
            LocalBusWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetContainerBackground()
                }
        }
        .configurationDisplayName("다음 버스")
        .description("장유·율하 시외버스 다음 출발 시간을 확인하세요")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
