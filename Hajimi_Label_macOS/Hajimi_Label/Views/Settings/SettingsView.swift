import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsModel
    
    var body: some View {
        Form {
            Section(header: Text(NSLocalizedString("appearance", comment: "Settings section header for appearance"))) {
                TextField(NSLocalizedString("grid_size", comment: "Grid size setting label"), value: $settings.gridSize, formatter: NumberFormatter())
                
                ColorPicker(NSLocalizedString("grid_color", comment: "Grid color setting label"), selection: Binding(
                    get: { settings.gridColor },
                    set: { settings.gridColorHex = $0.toHex() ?? "#333333" }
                ))
                
                ColorPicker(NSLocalizedString("bg_color", comment: "Background color setting label"), selection: Binding(
                    get: { settings.bgColor },
                    set: { settings.bgColorHex = $0.toHex() ?? "#1e1e1e" }
                ))
                
                TextField(NSLocalizedString("max_image_width", comment: "Max image width setting label"), value: $settings.maxImageWidth, formatter: NumberFormatter())
            }
            
            Section(header: Text(NSLocalizedString("behavior", comment: "Settings section header for behavior"))) {
                Toggle(NSLocalizedString("enable_overview", comment: "Enable overview toggle label"), isOn: $settings.enableOverview)
            }
        }
        .padding()
        .frame(maxWidth: 500)
    }
}


#Preview {
    SettingsView(settings: SettingsModel())
}
