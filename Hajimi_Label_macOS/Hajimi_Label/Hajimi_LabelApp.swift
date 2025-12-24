//
//  Hajimi_LabelApp.swift
//  Hajimi_Label
//
//  Created by shinonome on 17/12/2025.
//

import SwiftUI

/// The application delegate class responsible for handling application-level events.
/// Inherits from NSObject and conforms to NSApplicationDelegate protocol.
///
/// 应用程序代理类，负责处理应用级别的生命周期事件。
/// 继承自 NSObject 并遵循 NSApplicationDelegate 协议。
class AppDelegate: NSObject, NSApplicationDelegate {
    
    /// Called when the last window of the application is closed.
    /// Returns true to terminate the application, mimicking standard Windows behavior.
    ///
    /// 当应用程序的最后一个窗口关闭时调用。
    /// 返回 true 以终止应用程序，模仿 Windows 应用程序的标准行为（关闭窗口即退出）。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

/// The main entry point of the SwiftUI application.
/// The @main attribute identifies this struct as the entry point.
///
/// SwiftUI 应用程序的主入口点。
/// @main 属性将此结构体标识为程序的入口。
@main
struct Hajimi_LabelApp: App {
    // Connect the AppDelegate to the SwiftUI App lifecycle.
    // 将 AppDelegate 连接到 SwiftUI 的应用生命周期。
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Initialize the core data models as StateObjects.
    // @StateObject ensures these models persist for the lifetime of the app.
    //
    // 初始化核心数据模型为 StateObject。
    // @StateObject 确保这些模型在应用程序的整个生命周期内持续存在且只被初始化一次。
    @StateObject var appModel = AppModel()
    @StateObject var settings = SettingsModel()
    
    var body: some Scene {
        WindowGroup {
            // Inject the models into the main content view.
            // 将模型注入到主内容视图中。
            ContentView(appModel: appModel, settings: settings)
        }
        // Hide the standard system title bar for a custom UI look.
        // 隐藏标准系统标题栏，以实现自定义的 UI 外观。
        .windowStyle(.hiddenTitleBar)
    }
}
