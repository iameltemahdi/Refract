import CoreGraphics
import Foundation
import UniformTypeIdentifiers

enum SourceMode: String, CaseIterable, Identifiable {
    case photo = "Image", text = "Text", gradient = "Gradient"
    var id: Self { self }
}

enum GlassRegion: UInt32, CaseIterable, Identifiable, Codable {
    case full, top, bottom, left, right
    var id: Self { self }
    var name: String {
        switch self {
        case .full: "Entire canvas"
        case .top: "Top half"
        case .bottom: "Bottom half"
        case .left: "Left half"
        case .right: "Right half"
        }
    }
}

enum ImageFormat: String, CaseIterable, Identifiable {
    case png = "PNG", jpeg = "JPEG", tiff = "TIFF"
    var id: Self { self }
    var type: UTType {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        case .tiff: .tiff
        }
    }
}

enum ExportSize: String, CaseIterable, Identifiable {
    case original = "Source size", large = "4,000 px", medium = "2,400 px", small = "1,200 px"
    var id: Self { self }
    var longEdge: Int? {
        switch self {
        case .original: nil
        case .large: 4000
        case .medium: 2400
        case .small: 1200
        }
    }
}

enum PosterRatio: String, CaseIterable, Identifiable {
    case landscape = "3:2", square = "1:1", portrait = "4:5", wide = "16:9"
    var id: Self { self }
    var size: CGSize {
        switch self {
        case .landscape: .init(width: 3000, height: 2000)
        case .square: .init(width: 3000, height: 3000)
        case .portrait: .init(width: 2400, height: 3000)
        case .wide: .init(width: 3200, height: 1800)
        }
    }
}

struct Artwork {
    var mode: SourceMode = .photo
    var image: ImportedImage?
    var title = ""
    var typeface = "Heavy Sans"
    var textColor = RGB.black
    var paperColor = RGB.white
    var clearPaper = false
    var ratio: PosterRatio = .landscape
    var gradient: GradientArtwork?

    var canRender: Bool {
        switch mode {
        case .photo: image != nil
        case .text: !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .gradient: gradient != nil
        }
    }

    var size: CGSize {
        if mode == .photo, let image { return image.size }
        return ratio.size
    }
}

struct GlassSettings {
    var effect: GlassEffect
    var strength: Double
    var scale: Double
    var angle: Double
    var dispersion = 0.13
    var light = 0.59
    var microlens = false
    var lensAmount = 0.84
    var lensDensity = 92.0
    var region = GlassRegion.full
    var feather = 0.0
    var custom: CustomSurface?

    init(effect: GlassEffect = GlassEffect.all[0]) {
        self.effect = effect
        strength = effect.strength
        scale = effect.scale
        angle = effect.angle
    }

    func options(for artwork: Artwork, original: Bool) -> GlassOptions {
        let layer = custom
        return GlassOptions(
            strength: original ? 0 : Float(strength),
            scale: Float(scale), angle: Float(angle * .pi / 180), dispersion: Float(dispersion),
            light: Float(light), lensStrength: microlens ? Float(lensAmount) : 0,
            lensDensity: Float(lensDensity), feather: Float(feather), effect: effect.id,
            secondSurface: layer?.secondary ?? GlassLiquid, blend: Float(layer?.blend ?? 0),
            secondDensity: Float(layer?.density ?? 1), secondAngle: Float((layer?.angle ?? 0) * .pi / 180),
            phase: Float(layer?.phase ?? 0), stretch: Float(layer?.stretch ?? 1),
            source: artwork.mode == .gradient ? 1 : 0, region: region.rawValue,
            gradient: (artwork.gradient ?? GradientArtwork()).renderOptions
        )
    }
}

struct RGB {
    var red, green, blue: Double
    static let black = RGB(red: 0, green: 0, blue: 0)
    static let white = RGB(red: 1, green: 1, blue: 1)
    static let space = CGColorSpace(name: CGColorSpace.sRGB)!

    var cgColor: CGColor {
        CGColor(colorSpace: Self.space, components: [red, green, blue, 1])!
    }

    var renderColor: GlassColor {
        GlassColor(r: Float(red), g: Float(green), b: Float(blue))
    }

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init?(_ color: CGColor) {
        guard let components = color.converted(to: Self.space, intent: .defaultIntent, options: nil)?.components,
              components.count >= 3 else { return nil }
        red = min(max(components[0], 0), 1)
        green = min(max(components[1], 0), 1)
        blue = min(max(components[2], 0), 1)
    }
}

struct GradientArtwork {
    var start = RGB.white
    var end = RGB.black
    var angle = 32.0
    var radial = false

    var renderOptions: GlassGradient {
        let radians = angle * .pi / 180
        return GlassGradient(start: start.renderColor, end: end.renderColor,
                             cosine: Float(cos(radians)), sine: Float(sin(radians)), kind: radial ? 1 : 0)
    }
}

struct CustomSurface: Codable {
    var secondaryID = GlassLiquid.rawValue
    var blend = 0.42
    var density = 1.3
    var angle = 35.0
    var phase = 0.0
    var stretch = 1.0

    var secondary: GlassSurface {
        GlassEffect.all.first { $0.id.rawValue == secondaryID }?.id ?? GlassLiquid
    }
}

struct EffectPreset: Codable, Identifiable {
    var id = UUID()
    let name: String
    let primaryID: UInt32
    let surface: CustomSurface
    let strength, scale, angle, dispersion, light: Double
    let microlens: Bool
    let lensAmount, lensDensity: Double
    let region: GlassRegion
    let feather: Double

    init(name: String, settings: GlassSettings, surface: CustomSurface) {
        self.name = name
        primaryID = settings.effect.id.rawValue
        self.surface = surface
        strength = settings.strength
        scale = settings.scale
        angle = settings.angle
        dispersion = settings.dispersion
        light = settings.light
        microlens = settings.microlens
        lensAmount = settings.lensAmount
        lensDensity = settings.lensDensity
        region = settings.region
        feather = settings.feather
    }

    var settings: GlassSettings {
        var effect = GlassSettings(effect: GlassEffect.all.first { $0.id.rawValue == primaryID } ?? GlassEffect.all[0])
        effect.custom = surface
        effect.strength = strength
        effect.scale = scale
        effect.angle = angle
        effect.dispersion = dispersion
        effect.light = light
        effect.microlens = microlens
        effect.lensAmount = lensAmount
        effect.lensDensity = lensDensity
        effect.region = region
        effect.feather = feather
        return effect
    }
}
