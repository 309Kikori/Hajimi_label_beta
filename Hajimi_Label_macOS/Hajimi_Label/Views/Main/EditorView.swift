import SwiftUI

struct EditorView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var settings: SettingsModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar / Title
            HStack {
                Image(systemName: "photo")
                    .foregroundColor(.blue)
                Text(appModel.selectedFile?.lastPathComponent ?? "No File Selected")
                    .font(.system(size: 12))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            GeometryReader { geometry in
                if let selectedFile = appModel.selectedFile,
                   let image = NSImage(contentsOf: selectedFile) {
                    VStack(spacing: 0) {
                        ScrollView([.horizontal, .vertical]) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: settings.maxImageWidth > 0 ? CGFloat(settings.maxImageWidth) : nil)
                                .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                        }
                        .background(settings.bgColor)
                        
                        // Action Bar
                        HStack(spacing: 20) {
                            Spacer()
                            
                            Button(action: { appModel.labelCurrentFile(status: "fail") }) {
                                Text("Fail (F)")
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "a10000"))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .keyboardShortcut("f", modifiers: [])
                            
                            Button(action: { appModel.labelCurrentFile(status: "invalid") }) {
                                Text("Invalid (I)")
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "8e8e8e"))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .keyboardShortcut("i", modifiers: [])
                            
                            Button(action: { appModel.labelCurrentFile(status: "pass") }) {
                                Text("Pass (P)")
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "0e639c"))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .keyboardShortcut("p", modifiers: [])
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(nsColor: .windowBackgroundColor))
                    }
                } else {
                    VStack {
                        Spacer()
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No Image Selected")
                            .font(.title)
                            .foregroundColor(.secondary)
                            .padding(.top)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(settings.bgColor)
                }
            }
        }
    }
}
