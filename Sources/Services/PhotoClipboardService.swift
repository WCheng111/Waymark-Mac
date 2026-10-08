import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Owns only a newly-created staging directory, never the user's source file.
/// Drafts (including the import task's snapshot) keep it alive until finished.
final class TemporaryPhotoSource {
    let url: URL
    private let directory: URL

    init(data: Data, fileExtension: String) throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Waymark-paste-\(UUID().uuidString)", isDirectory: true)
        url = directory.appendingPathComponent("粘贴的照片.\(fileExtension)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    deinit { try? FileManager.default.removeItem(at: directory) }
}

enum PhotoClipboardService {
    /// Read only on an explicit paste action. Prefer original files (EXIF and
    /// full resolution) over image previews advertised by the same item.
    @MainActor
    static func makeDrafts(from pasteboard: NSPasteboard = .general) throws -> [ImportedPhotoDraft] {
        var drafts: [ImportedPhotoDraft] = []
        var seenFiles = Set<URL>()
        for item in pasteboard.pasteboardItems ?? [] {
            if let value = item.string(forType: .fileURL),
               let url = URL(string: value), url.isFileURL {
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                let files = PhotoImportService.makeDrafts(from: [url]).filter {
                    guard let source = CGImageSourceCreateWithURL($0.sourceURL as CFURL, nil) else { return false }
                    return CGImageSourceGetCount(source) > 0
                }
                if !files.isEmpty {
                    drafts += files.filter { seenFiles.insert($0.sourceURL.standardizedFileURL).inserted }
                    continue
                }
            }

            // A screenshot/browser image commonly offers both PNG and TIFF.
            // Consume one representation per item so it isn't imported twice.
            let types = ([NSPasteboard.PasteboardType.png, .tiff] + item.types)
                .filter { UTType($0.rawValue)?.conforms(to: .image) == true }
            for type in types {
                guard let data = item.data(forType: type),
                      let source = CGImageSourceCreateWithData(data as CFData, nil),
                      CGImageSourceGetCount(source) > 0,
                      let identifier = CGImageSourceGetType(source) as String?,
                      let ext = UTType(identifier)?.preferredFilenameExtension else { continue }
                let temporary = try TemporaryPhotoSource(data: data, fileExtension: ext)
                guard var draft = PhotoImportService.makeDraft(from: temporary.url) else { continue }
                draft.temporarySource = temporary
                drafts.append(draft)
                break
            }
        }
        return drafts
    }
}
