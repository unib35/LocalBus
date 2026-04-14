//
//  LocalBusWidgetBundle.swift
//  LocalBusWidget
//

import WidgetKit
import SwiftUI

@main
struct LocalBusWidgetBundle: WidgetBundle {
    var body: some Widget {
        LocalBusConfigurableWidget()
        if #available(iOS 16.2, *) {
            BusLiveActivityView()
        }
    }
}
