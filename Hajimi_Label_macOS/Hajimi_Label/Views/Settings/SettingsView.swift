import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsModel
    
    var body: some View {
        Form {
            Section(header: Text("Appearance")) {
                TextField("Grid Size", value: $settings.gridSize, formatter: NumberFormatter())
                
                ColorPicker("Grid Color", selection: Binding(
                    get: { settings.gridColor },
                    set: { settings.gridColorHex = $0.toHex() ?? "#333333" }
                ))
                
                ColorPicker("Background Color", selection: Binding(
                    get: { settings.bgColor },
                    set: { settings.bgColorHex = $0.toHex() ?? "#1e1e1e" }
                ))
                
                TextField("Max Image Width", value: $settings.maxImageWidth, formatter: NumberFormatter())
            }
            
            Section(header: Text("Behavior")) {
                Toggle("Enable Overview", isOn: $settings.enableOverview)
            }
        }
        .padding()
        .frame(maxWidth: 500)
    }
}


