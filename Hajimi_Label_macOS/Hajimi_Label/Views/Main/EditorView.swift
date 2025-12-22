import SwiftUI

struct EditorView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var settings: SettingsModel
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar / Title
            HStack {
                Image(systemName: "photo")
                    .foregroundColor(Color(hex: "007acc"))
                Text(appModel.selectedFile?.lastPathComponent ?? NSLocalizedString("no_file_selected", comment: ""))
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            GeometryReader { geometry in
                if let selectedFile = appModel.selectedFile,
                   let image = NSImage(contentsOf: selectedFile) {
                    ZStack {
                        // Checkerboard Background
                        CheckerboardView()
                            .opacity(0.5)
                        
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(settings.bgColor)
                    .clipped()
                    .overlay(
                        ScrollWheelHandler { zoomFactor in
                            let newScale = scale * zoomFactor
                            scale = max(0.1, min(newScale, 10.0))
                        }
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    self.offset = CGSize(width: self.lastOffset.width + value.translation.width, height: self.lastOffset.height + value.translation.height)
                                }
                                .onEnded { _ in
                                    self.lastOffset = self.offset
                                }
                        )
                    )
                    .overlay(
                        // Action Bar (Floating at bottom)
                        HStack(spacing: 20) {
                            Spacer()
                            
                            Button(action: { appModel.labelCurrentFile(status: "fail") }) {
                                Text("\(NSLocalizedString("fail", comment: "")) (F)")
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "a10000"))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .keyboardShortcut("f", modifiers: [])
                            
                            Button(action: { appModel.labelCurrentFile(status: "invalid") }) {
                                Text("\(NSLocalizedString("invalid", comment: "")) (I)")
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "8e8e8e"))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .keyboardShortcut("i", modifiers: [])
                            
                            Button(action: { appModel.labelCurrentFile(status: "pass") }) {
                                Text("\(NSLocalizedString("pass", comment: "")) (P)")
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
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
                        , alignment: .bottom
                    )
                } else {
                    VStack {
                        Spacer()
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("no_file_selected")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(settings.bgColor)
                }
            }
            .onChange(of: appModel.selectedFile) { _, _ in
                scale = 1.0
                offset = .zero
                lastOffset = .zero
            }
        }
    }
}

struct EditorView_Previews: PreviewProvider {
    static var previews: some View {
        EditorView(appModel: AppModel(), settings: SettingsModel())
    }
}
