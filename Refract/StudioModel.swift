import CoreGraphics
import Foundation
import Combine

@MainActor
final class StudioModel: ObservableObject {
    @Published var artwork = Artwork() { didSet { schedulePreview() } }
    @Published var options = GlassSettings() { didSet { schedulePreview() } }
    @Published var importedName: String?
    @Published var preview: CGImage?
    @Published var original = false { didSet { schedulePreview() } }
    @Published var error: String?
    @Published private(set) var importing = false
    @Published private(set) var exporting = false
    @Published var showExport = false
    @Published var dropping = false
    @Published var showImporter = false
    @Published var export: ArtworkFile?
    @Published var showEffects = false
    @Published var showInspector = false
    @Published var showWorkshop = false
    @Published var presentingExport = false
    @Published var presetName = ""
    @Published var presetNotice: String?
    @Published var previewZoom = 1.0
    var zoomAtGestureStart: Double?
    #if os(iOS)
    @Published var showPhotoPicker = false
    #endif
    @Published private(set) var presets: [EffectPreset] = []
    @Published var format = ImageFormat.png
    @Published var exportSize = ExportSize.original
    @Published var printResolution = true
    @Published var status: String?

    private let previewQueue = DispatchQueue(label: "studio.refract.preview", qos: .userInitiated)
    private let importQueue = DispatchQueue(label: "studio.refract.import", qos: .userInitiated)
    private var pendingPreview: DispatchWorkItem?
    private var importRequest = UUID()
    private var previewRequest = UUID()
    private let defaults: UserDefaults
    private let presetKey = "refract.effectPresets"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: presetKey),
           let presets = try? JSONDecoder().decode([EffectPreset].self, from: data) {
            self.presets = presets
        }
    }

    func schedulePreview() {
        pendingPreview?.cancel()
        let art = artwork, settings = options, before = original
        let revision = UUID()
        previewRequest = revision
        guard art.canRender else {
            preview = nil
            return
        }
        let size = GlassRenderer.fittedSize(art.size, longEdge: 1040)
        let request = DispatchWorkItem { [weak self] in
            let image = try? GlassRenderer.shared.render(art, settings: settings, size: size, original: before)
            DispatchQueue.main.async {
                guard let self, self.previewRequest == revision else { return }
                self.preview = image
            }
        }
        pendingPreview = request
        previewQueue.asyncAfter(deadline: .now() + .milliseconds(32), execute: request)
    }

    func choose(_ effect: GlassEffect) {
        var setting = options
        setting.effect = effect
        setting.custom = nil
        setting.scale = effect.scale
        setting.angle = effect.angle
        setting.strength = effect.strength
        options = setting
        original = false
    }

    func reset() {
        let custom = options.custom
        var defaults = GlassSettings(effect: options.effect)
        defaults.custom = custom
        options = defaults
        original = false
    }

    func selectSource(_ mode: SourceMode) {
        guard artwork.mode != mode else { return }
        importRequest = UUID()
        importing = false
        preview = nil
        original = false
        status = nil
        previewZoom = 1
        zoomAtGestureStart = nil
        artwork.mode = mode
    }

    func createGradient() {
        artwork.gradient = GradientArtwork()
    }

    func removeGradient() {
        artwork.gradient = nil
    }

    func beginCustomEffect() {
        if options.custom == nil {
            options.custom = CustomSurface()
        }
        original = false
    }

    func savePreset(name: String) {
        guard let surface = options.custom else { return }
        let title = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        guard !title.isEmpty else { return }

        var updated = presets
        if let index = updated.firstIndex(where: { $0.name.caseInsensitiveCompare(title) == .orderedSame }) {
            let id = updated[index].id
            updated[index] = EffectPreset(name: title, settings: options, surface: surface)
            updated[index].id = id
        } else {
            updated.append(EffectPreset(name: title, settings: options, surface: surface))
        }
        if savePresets(updated) { presetNotice = "Saved " + title }
    }

    func apply(_ preset: EffectPreset) {
        presetNotice = nil
        options = preset.settings
        original = false
    }

    func delete(_ preset: EffectPreset) {
        if savePresets(presets.filter { $0.id != preset.id }) { presetNotice = nil }
    }

    private func savePresets(_ updated: [EffectPreset]) -> Bool {
        do {
            let data = try JSONEncoder().encode(updated)
            defaults.set(data, forKey: presetKey)
            presets = updated
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func load(_ url: URL) {
        importArtwork(named: url.lastPathComponent) {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            return try GlassRenderer.shared.load(url)
        }
    }

    func loadPhoto(_ data: Data) {
        importArtwork(named: "Photo") {
            try GlassRenderer.shared.loadImageData(data)
        }
    }

    private func importArtwork(named name: String, read: @escaping () throws -> ImportedImage) {
        let request = UUID()
        importRequest = request
        importing = true
        importQueue.async { [weak self] in
            let result = Result(catching: read)
            DispatchQueue.main.async {
                guard let self, self.importRequest == request else { return }
                self.importing = false
                switch result {
                case .success(let image):
                    var imported = self.artwork
                    imported.image = image
                    imported.mode = .photo
                    self.preview = nil
                    self.original = false
                    self.status = nil
                    self.importedName = name
                    self.previewZoom = 1
                    self.zoomAtGestureStart = nil
                    self.artwork = imported
                case .failure(let error):
                    self.error = error.localizedDescription
                }
            }
        }
    }

    var exportDimensions: CGSize {
        GlassRenderer.fittedSize(artwork.size, longEdge: exportSize.longEdge)
    }

    var canExport: Bool { artwork.canRender && !importing && !exporting }

    func prepareExport() {
        guard canExport else { return }
        let art = artwork
        let settings = options
        let size = exportDimensions
        let format = format
        let dpi = printResolution ? 300 : 72
        let basename = importedName.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
        let title = art.mode == .photo ? basename ?? "Artwork" : "Refract"
        let effectName = settings.custom == nil ? settings.effect.name : "Custom"
        exporting = true
        export = nil
        status = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result {
                let image = try GlassRenderer.shared.render(art, settings: settings, size: size)
                let data = try GlassRenderer.shared.encode(image, format: format, dpi: dpi)
                return ArtworkFile(data: data, filename: title + " - " + effectName, format: format)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.exporting = false
                switch result {
                case .success(let file): self.export = file
                case .failure(let error): self.error = error.localizedDescription
                }
            }
        }
    }
}
