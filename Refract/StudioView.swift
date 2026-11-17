import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif
#if os(iOS)
import PhotosUI
#endif

struct StudioView: View {
    @ObservedObject var model: StudioModel
    @Environment(\.colorScheme) private var appearance
    private var background: Color { appearance == .dark ? Color(white: 0.09) : Color(white: 0.97) }
    private var panel: Color { appearance == .dark ? Color(white: 0.13) : .white }
    private var canvas: Color { appearance == .dark ? .black : Color(white: 0.91) }

    var body: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width >= 1020
            VStack(spacing: 0) {
                toolbar(wide: wide)
                Divider()
                HStack(spacing: 0) {
                    if wide {
                        effectList().frame(width: 186)
                        Divider()
                    }
                    editor
                    if wide {
                        Divider()
                        inspector.frame(width: 242)
                    }
                }
            }
        }
        .background(background)
        .tint(appearance == .dark ? .white : .black)
        .sheet(isPresented: $model.showEffects) {
            panelSheet("Effects") { effectList(onSelection: { model.showEffects = false }) }
        }
        .sheet(isPresented: $model.showInspector) {
            panelSheet("Adjustments") { inspector }
        }
        .sheet(isPresented: $model.showWorkshop) {
            EffectWorkshop(model: model)
        }
        .sheet(isPresented: $model.showExport, onDismiss: presentPendingExport) {
            exportOptions
        }
        .fileImporter(isPresented: $model.showImporter, allowedContentTypes: [.image, .pdf]) { result in
            switch result {
            case .success(let url): model.load(url)
            case .failure(let error): model.error = error.localizedDescription
            }
        }
        .fileExporter(isPresented: $model.presentingExport, document: model.export,
                      contentType: model.export?.format.type ?? .png, defaultFilename: model.export?.filename) { result in
            model.export = nil
            switch result {
            case .success(let url): model.status = "Exported " + url.lastPathComponent
            case .failure(let error): model.error = error.localizedDescription
            }
        }
        .onChange(of: model.export != nil) { _ in presentPendingExport() }
        .alert("Refract", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK", role: .cancel) { model.error = nil }
        } message: {
            Text(model.error ?? "")
        }
        #if os(iOS)
        .sheet(isPresented: $model.showPhotoPicker) {
            PhotoPicker { result in
                model.showPhotoPicker = false
                switch result {
                case .success(let data): model.loadPhoto(data)
                case .failure(let error): model.error = error.localizedDescription
                }
            } onCancel: {
                model.showPhotoPicker = false
            }
            .ignoresSafeArea()
        }
        #endif
    }

    private func presentPendingExport() {
        if model.export != nil && !model.showExport { model.presentingExport = true }
    }

    private func toolbar(wide: Bool) -> some View {
        HStack(spacing: 6) {
            Text("Refract").font(.system(size: 20, weight: .semibold)).tracking(-0.6)
            Spacer(minLength: 4)
            if !wide {
                iconButton("Effects", icon: "square.grid.2x2") { model.showEffects = true }
                iconButton("Adjustments", icon: "slider.horizontal.3") { model.showInspector = true }
            }
            Button {
                model.showWorkshop = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "wand.and.stars")
                    if wide { Text("Custom Effects") }
                }
                .frame(minWidth: 44, minHeight: 44)
                .padding(.horizontal, wide ? 8 : 0)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Custom Effects")
            .help("Custom Effects")
            iconButton("Open Image", icon: "folder") { model.showImporter = true }
            Button {
                model.showExport = true
            } label: {
                if model.exporting {
                    ProgressView().controlSize(.small).frame(minWidth: 28, minHeight: 26)
                } else {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                        if wide { Text("Export") }
                    }
                    .frame(minWidth: 27, minHeight: 26)
                }
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .padding(.horizontal, wide ? 8 : 0)
            .foregroundStyle(panel)
            .background(.primary, in: Capsule())
            .opacity(model.canExport ? 1 : 0.36)
            .disabled(!model.canExport)
            .help("Export")
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 59)
        .background(.regularMaterial)
    }

    private func iconButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)
    }

    private func panelSheet<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button("Done") {
                    model.showEffects = false
                    model.showInspector = false
                }
                .frame(minHeight: 44)
            }
            .padding(.horizontal, 16)
            Divider()
            content()
        }
        #if os(macOS)
        .frame(width: 340, height: 550)
        #endif
    }

    private func effectList(onSelection: @escaping () -> Void = {}) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                Text("Surfaces").font(.headline).padding(.horizontal, 8).padding(.vertical, 7)
                ForEach(GlassEffect.all) { effect in
                    let selected = model.options.custom == nil && model.options.effect.id == effect.id
                    Button {
                        model.choose(effect)
                        onSelection()
                    } label: {
                        HStack(spacing: 9) {
                            SurfaceIcon(surface: effect.id, selected: selected)
                            Text(effect.name).font(.subheadline.weight(selected ? .semibold : .regular))
                            Spacer(minLength: 2)
                            if selected {
                                Image(systemName: "checkmark").font(.caption.weight(.semibold))
                            }
                        }
                        .padding(.horizontal, 7)
                        .frame(minHeight: 44)
                        .background(selected ? Color.primary.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(9)
        }
        .frame(maxHeight: .infinity)
        .background(panel)
    }

    private var editor: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Picker("Source", selection: Binding(get: { model.artwork.mode }, set: model.selectSource)) {
                    ForEach(SourceMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(minHeight: 46)
                .frame(maxWidth: 300)
                Spacer(minLength: 0)
                if model.previewZoom > 1 {
                    iconButton("Fit Artwork", icon: "arrow.down.right.and.arrow.up.left") {
                        model.previewZoom = 1
                    }
                }
                iconButton(model.original ? "Show Effect" : "Show Original", icon: model.original ? "circle.fill" : "circle.lefthalf.filled") {
                    model.original.toggle()
                }
                .disabled(!model.artwork.canRender)
            }
            .padding(.horizontal, 11)
            Divider()
            ZStack {
                canvas
                if model.importing {
                    ProgressView("Opening image…")
                } else if model.artwork.canRender {
                    preview
                } else {
                    emptyCanvas
                }
                if model.dropping {
                    canvas.opacity(0.85)
                    Label("Drop to open", systemImage: "arrow.down.to.line").font(.headline)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $model.dropping, perform: acceptDrop)
            Divider()
            HStack {
                Text(statusLine).lineLimit(1).truncationMode(.middle)
                Spacer()
                if model.artwork.canRender {
                    Text(dimensions(model.artwork.size)).monospacedDigit()
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .frame(height: 29)
        }
    }

    private var statusLine: String {
        if let status = model.status { return status }
        switch model.artwork.mode {
        case .photo: return model.importedName ?? "No image open"
        case .text: return "Text"
        case .gradient: return "Gradient"
        }
    }

    private var preview: some View {
        ZStack {
            if let image = model.preview {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .background(Checkerboard())
                    .scaleEffect(model.previewZoom)
                    .modifier(PreviewZoom(model: model))
                    .accessibilityLabel(model.original ? "Original artwork" : "Refracted artwork")
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var emptyCanvas: some View {
        VStack(spacing: 12) {
            switch model.artwork.mode {
            case .photo:
                emptyTitle("Open an image", subtitle: "Drop a file here or choose one.", icon: "photo.on.rectangle")
                Button("Choose File…") { model.showImporter = true }.buttonStyle(.borderedProminent)
                #if os(iOS)
                Button("Choose Photo…") { model.showPhotoPicker = true }.buttonStyle(.bordered)
                #endif
            case .gradient:
                emptyTitle("Create a gradient", subtitle: "Choose colors and a direction to make your own.", icon: "circle.righthalf.filled")
                Button("New Gradient") {
                    model.createGradient()
                }
                .buttonStyle(.borderedProminent)
            case .text:
                emptyTitle("Add text", subtitle: "Enter text to use it as your artwork.", icon: "textformat")
                Button("Add Text…") { model.showInspector = true }.buttonStyle(.borderedProminent)
            }
        }
        .controlSize(.large)
        .padding(16)
        .multilineTextAlignment(.center)
    }

    private func emptyTitle(_ title: String, subtitle: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 33, weight: .light)).accessibilityHidden(true)
            Text(title).font(.title2.weight(.semibold))
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if model.artwork.mode == .text || (model.artwork.mode == .gradient && model.artwork.gradient != nil) {
                    sourceOptions
                    Divider()
                }
                HStack {
                    Text(model.options.custom == nil ? "Refraction" : "Custom Effect").font(.headline)
                    Spacer()
                    Button("Reset", action: model.reset).font(.caption)
                }
                RefractionControls(settings: $model.options)
                Divider()
                Toggle("Microlens", isOn: $model.options.microlens).toggleStyle(.switch)
                if model.options.microlens {
                    ValueSlider("Texture", value: $model.options.lensAmount, range: 0...1, unit: .percent)
                    ValueSlider("Lens density", value: $model.options.lensDensity, range: 22...180)
                }
                Divider()
                Picker("Coverage", selection: $model.options.region) {
                    ForEach(GlassRegion.allCases) { Text($0.name).tag($0) }
                }
                if model.options.region != .full {
                    ValueSlider("Feather", value: $model.options.feather, range: 0...0.25, unit: .percent)
                }
            }
            .padding(14)
        }
        .background(panel)
    }

    private var sourceOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.artwork.mode == .text {
                TextField("Text", text: $model.artwork.title, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .onChange(of: model.artwork.title) { value in
                        if value.count > 240 { model.artwork.title = String(value.prefix(240)) }
                    }
                Picker("Typeface", selection: $model.artwork.typeface) {
                    ForEach(["Heavy Sans", "Serif", "Mono"], id: \.self) { Text($0) }
                }
                ColorPicker("Ink", selection: colorBinding($model.artwork.textColor), supportsOpacity: false)
                ColorPicker("Paper", selection: colorBinding($model.artwork.paperColor), supportsOpacity: false)
                    .disabled(model.artwork.clearPaper)
                Toggle("Transparent", isOn: $model.artwork.clearPaper)
            } else if let gradient = Binding($model.artwork.gradient) {
                ColorPicker("Start color", selection: colorBinding(gradient.start), supportsOpacity: false)
                ColorPicker("End color", selection: colorBinding(gradient.end), supportsOpacity: false)
                Toggle("Radial", isOn: gradient.radial)
                if !gradient.radial.wrappedValue {
                    ValueSlider("Direction", value: gradient.angle, range: -180...180, unit: .degrees)
                }
                Button("Clear Gradient", role: .destructive, action: model.removeGradient)
            }
            Picker("Canvas", selection: $model.artwork.ratio) {
                ForEach(PosterRatio.allCases) { Text($0.rawValue).tag($0) }
            }
        }
    }

    private var exportOptions: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Export Artwork").font(.title2.weight(.semibold))
            Picker("Format", selection: $model.format) {
                ForEach(ImageFormat.allCases) { Text($0.rawValue).tag($0) }
            }
            Picker("Resolution", selection: $model.exportSize) {
                ForEach(ExportSize.allCases) { Text($0.rawValue).tag($0) }
            }
            Toggle("300 DPI for print", isOn: $model.printResolution)
            Text(dimensions(model.exportDimensions) + " px · sRGB").font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { model.showExport = false }.keyboardShortcut(.cancelAction)
                Button("Continue…") {
                    model.prepareExport()
                    model.showExport = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(minWidth: 300, idealWidth: 355)
        #if os(iOS)
        .presentationDetents([.medium])
        #endif
    }

    private func colorBinding(_ binding: Binding<RGB>) -> Binding<Color> {
        Binding(get: { Color(cgColor: binding.wrappedValue.cgColor) }, set: { color in
            #if os(macOS)
            let resolved = NSColor(color).cgColor
            #else
            let resolved = UIColor(color).cgColor
            #endif
            if let rgb = RGB(resolved) { binding.wrappedValue = rgb }
        })
    }

    private func dimensions(_ size: CGSize) -> String { "\(Int(size.width)) × \(Int(size.height))" }

    private func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            let url = item as? URL ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
            DispatchQueue.main.async {
                if let url { model.load(url) }
                else { model.error = error?.localizedDescription ?? StudioError.badImage.localizedDescription }
            }
        }
        return true
    }
}

private struct PreviewZoom: ViewModifier {
    @ObservedObject var model: StudioModel

    func body(content: Content) -> some View {
        #if compiler(>=6.4) && os(macOS)
        if #available(macOS 27, *) {
            content.gesture(MagnifyGesture(inputKinds: .all)
                .onChanged { update($0.magnification) }
                .onEnded { _ in model.zoomAtGestureStart = nil })
        } else {
            content.gesture(legacyGesture)
        }
        #else
        content.gesture(legacyGesture)
        #endif
    }

    private var legacyGesture: some Gesture {
        MagnificationGesture()
            .onChanged(update)
            .onEnded { _ in model.zoomAtGestureStart = nil }
    }

    private func update(_ factor: CGFloat) {
        let start = model.zoomAtGestureStart ?? model.previewZoom
        model.zoomAtGestureStart = start
        model.previewZoom = min(4, max(1, start * factor))
    }
}

private struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let side: CGFloat = 12
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.40)))
            var tiles = Path()
            for row in 0..<Int(ceil(size.height / side)) {
                for column in stride(from: row % 2, to: Int(ceil(size.width / side)), by: 2) {
                    tiles.addRect(CGRect(x: CGFloat(column) * side, y: CGFloat(row) * side, width: side, height: side))
                }
            }
            context.fill(tiles, with: .color(Color(white: 0.55)))
        }
        .accessibilityHidden(true)
    }
}

#if os(iOS)
private struct PhotoPicker: UIViewControllerRepresentable {
    let onPick: (Result<Data, Error>) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onCancel: onCancel) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (Result<Data, Error>) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (Result<Data, Error>) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                onCancel()
                return
            }
            let type = provider.registeredTypeIdentifiers.first { UTType($0)?.conforms(to: .image) == true }
            provider.loadDataRepresentation(forTypeIdentifier: type ?? UTType.image.identifier) { data, error in
                DispatchQueue.main.async {
                    if let data { self.onPick(.success(data)) }
                    else { self.onPick(.failure(error ?? StudioError.badImage)) }
                }
            }
        }
    }
}
#endif
