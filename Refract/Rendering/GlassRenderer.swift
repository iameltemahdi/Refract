import CoreGraphics
import CoreText
import Foundation
import ImageIO

enum StudioError: LocalizedError {
    case badImage, failedRender, failedExport, excessiveSize
    var errorDescription: String? {
        switch self {
        case .badImage: "This file could not be opened as an image or PDF graphic."
        case .failedRender: "The artwork could not be rendered."
        case .failedExport: "The image could not be written to the selected folder."
        case .excessiveSize: "This canvas is larger than 64 megapixels. Choose a smaller export size."
        }
    }
}

struct ImportedImage {
    enum Backing {
        case file(CGImageSource)
        case raster(CGImage)
    }

    let backing: Backing
    let size: CGSize

    func image(for target: CGSize) throws -> CGImage {
        switch backing {
        case .raster(let graphic):
            return graphic
        case .file(let source):
            let maxDimension = Int(min(max(target.width, target.height), max(size.width, size.height)))
            let properties: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension,
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, properties as CFDictionary)
            else { throw StudioError.badImage }
            return decoded
        }
    }
}

final class GlassRenderer {
    static let shared = GlassRenderer()
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)

    func load(_ url: URL) throws -> ImportedImage {
        if url.pathExtension.lowercased() == "pdf" {
            guard let page = CGPDFDocument(url as CFURL)?.page(at: 1) else { throw StudioError.badImage }
            let bounds = page.getBoxRect(.cropBox)
            guard bounds.width > 0, bounds.height > 0 else { throw StudioError.badImage }
            let size = Self.fittedSize(bounds.size, longEdge: 3500)
            let context = try bitmap(size)
            let target = CGRect(origin: .zero, size: size)
            context.concatenate(page.getDrawingTransform(.cropBox, rect: target, rotate: 0, preserveAspectRatio: true))
            context.drawPDFPage(page)
            guard let image = context.makeImage() else { throw StudioError.badImage }
            return ImportedImage(backing: .raster(image), size: size)
        }
        return try loadImageData(Data(contentsOf: url))
    }

    func loadImageData(_ data: Data) throws -> ImportedImage {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int, width > 0,
              let height = properties[kCGImagePropertyPixelHeight] as? Int, height > 0
        else { throw StudioError.badImage }
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        let size = (5...8).contains(orientation)
            ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
        let artwork = ImportedImage(backing: .file(source), size: size)
        _ = try artwork.image(for: Self.fittedSize(size, longEdge: 450))
        return artwork
    }

    static func fittedSize(_ size: CGSize, longEdge: Int?) -> CGSize {
        let scale = longEdge.map { CGFloat($0) / max(size.width, size.height) } ?? 1
        return CGSize(width: max(1, (size.width * scale).rounded()), height: max(1, (size.height * scale).rounded()))
    }

    private func bitmap(_ size: CGSize) throws -> CGContext {
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                                      bytesPerRow: Int(size.width) * 4, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
        else { throw StudioError.failedRender }
        return context
    }

    private func textBitmap(_ artwork: Artwork, size: CGSize) throws -> CGContext {
        let canvas = try bitmap(size)
        if !artwork.clearPaper {
            canvas.setFillColor(artwork.paperColor.cgColor)
            canvas.fill(CGRect(origin: .zero, size: size))
        }
        let content = artwork.title.trimmingCharacters(in: .newlines)
        let lines = content.isEmpty ? [""] : content.components(separatedBy: .newlines)
        let maximum = min(size.height * 0.55, size.height * 0.95 / CGFloat(lines.count))
        let fontName: String
        switch artwork.typeface {
        case "Mono": fontName = "Menlo-Bold"
        case "Serif": fontName = "Georgia-Bold"
        default: fontName = "HelveticaNeue-Bold"
        }

        func typeset(_ font: CTFont) -> [CTLine] {
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): artwork.textColor.cgColor
            ]
            return lines.map { CTLineCreateWithAttributedString(NSAttributedString(string: $0, attributes: attributes)) }
        }
        let draft = CTFontCreateWithName(fontName as CFString, maximum, nil)
        let widest = typeset(draft).map { CTLineGetTypographicBounds($0, nil, nil, nil) }.max() ?? 0
        let font = CTFontCreateWithName(fontName as CFString, maximum * min(1, size.width * 0.83 / max(widest, 1)), nil)
        let step = CTFontGetSize(font) * 1.05
        let height = step * CGFloat(lines.count - 1) + CTFontGetAscent(font) + CTFontGetDescent(font)
        let firstY = (size.height + height) / 2 - CTFontGetAscent(font)
        canvas.textMatrix = .identity
        for (index, line) in typeset(font).enumerated() {
            let width = CTLineGetTypographicBounds(line, nil, nil, nil)
            canvas.textPosition = CGPoint(x: (size.width - width) / 2, y: firstY - CGFloat(index) * step)
            CTLineDraw(line, canvas)
        }
        return canvas
    }

    func render(_ artwork: Artwork, settings: GlassSettings, size: CGSize, original: Bool = false) throws -> CGImage {
        guard artwork.canRender else { throw StudioError.failedRender }
        let width = Int(size.width), height = Int(size.height)
        guard width > 0, height > 0, Double(width) * Double(height) <= 64_000_000 else { throw StudioError.excessiveSize }
        let output = try bitmap(size)
        let source: CGContext?
        switch artwork.mode {
        case .gradient:
            source = nil
        case .text:
            source = try textBitmap(artwork, size: size)
        case .photo:
            guard let image = artwork.image else { throw StudioError.badImage }
            let plate = try image.image(for: size)
            let bitmap = try bitmap(size)
            bitmap.interpolationQuality = .high
            bitmap.setBlendMode(.copy)
            bitmap.draw(plate, in: CGRect(origin: .zero, size: size))
            source = bitmap
        }
        guard let destination = output.data?.assumingMemoryBound(to: UInt8.self) else { throw StudioError.failedRender }
        withExtendedLifetime(source) {
            glassRender(source?.data?.assumingMemoryBound(to: UInt8.self), UInt32(width), UInt32(height),
                        destination, UInt32(width), UInt32(height), settings.options(for: artwork, original: original))
        }
        guard let result = output.makeImage() else { throw StudioError.failedRender }
        return result
    }

    func encode(_ image: CGImage, format: ImageFormat, dpi: Int) throws -> Data {
        let bytes = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(bytes, format.type.identifier as CFString, 1, nil)
        else { throw StudioError.failedExport }
        let flattened: CGImage
        if format == .jpeg {
            let size = CGSize(width: image.width, height: image.height)
            let context = try bitmap(size)
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            let rect = CGRect(origin: .zero, size: size)
            context.fill(rect)
            context.draw(image, in: rect)
            guard let opaque = context.makeImage() else { throw StudioError.failedExport }
            flattened = opaque
        } else {
            flattened = image
        }
        var options: [CFString: Any] = [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi]
        if format == .jpeg { options[kCGImageDestinationLossyCompressionQuality] = 0.95 }
        CGImageDestinationAddImage(destination, flattened, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw StudioError.failedExport }
        return bytes as Data
    }
}
