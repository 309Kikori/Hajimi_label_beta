//
//  Hajimi_LabelApp.swift
//  Hajimi_Label
//
//  Created by shinonome on 17/12/2025.
//

import SwiftUI

@main
struct Hajimi_LabelApp: App {
    @StateObject var appModel = AppModel()
    @StateObject var settings = SettingsModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView(appModel: appModel, settings: settings)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
