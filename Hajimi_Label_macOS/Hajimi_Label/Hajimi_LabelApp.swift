//
//  Hajimi_LabelApp.swift
//  Hajimi_Label
//
//  Created by shinonome on 17/12/2025.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

@main
struct Hajimi_LabelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var appModel = AppModel()
    @StateObject var settings = SettingsModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView(appModel: appModel, settings: settings)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
