//
//  TheLoggerWidget.swift
//  TheLoggerWidget
//
//  Live Activity only - no regular widgets needed
//

import WidgetKit
import SwiftUI

// MARK: - Widget Bundle (Live Activity Only)

@main
struct TheLoggerWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
    }
}
