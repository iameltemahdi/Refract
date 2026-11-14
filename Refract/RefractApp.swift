import SwiftUI

@main
struct RefractApp: App {
    @StateObject private var model = StudioModel()

    var body: some Scene {
        #if os(macOS)
        Window("Refract", id: "studio") {
            StudioView(model: model)
                .frame(minWidth: 700, minHeight: 520)
                .onOpenURL(perform: model.load)
        }
        .defaultSize(width: 1120, height: 735)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Image…") { model.showImporter = true }
                    .keyboardShortcut("o")
                Button("Export…") { model.showExport = true }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(!model.canExport)
            }
            CommandMenu("Glass") {
                Button(model.original ? "Show Effect" : "Show Original") { model.original.toggle() }
                    .keyboardShortcut("b")
                    .disabled(!model.artwork.canRender)
                Button("Toggle Microlens") { model.options.microlens.toggle() }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                Button("Reset Adjustments", action: model.reset)
            }
        }
        #else
        WindowGroup {
            StudioView(model: model).onOpenURL(perform: model.load)
        }
        #endif
    }
}
