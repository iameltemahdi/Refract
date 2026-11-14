import SwiftUI
import UniformTypeIdentifiers

struct ArtworkFile: FileDocument {
    static let readableContentTypes: [UTType] = [.png, .jpeg, .tiff]

    let data: Data
    let filename: String
    let format: ImageFormat

    init(data: Data, filename: String, format: ImageFormat) {
        self.data = data
        self.filename = filename
        self.format = format
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let format = ImageFormat.allCases.first(where: { configuration.contentType.conforms(to: $0.type) })
        else { throw CocoaError(.fileReadCorruptFile) }
        self.init(data: data, filename: configuration.file.preferredFilename ?? "Refract", format: format)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
