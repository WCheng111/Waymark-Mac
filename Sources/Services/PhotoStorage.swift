import AppKit
import ImageIO
import UniformTypeIdentifiers

enum PhotoStorageError: Error {
    case unreadableSource
    case encodingFailed
}

/// Owns where imported photo bytes live on disk. Same contract as the iPhone
/// app's `PhotoStorage`, but the Mac imports from arbitrary files on disk
/// (Finder drag, open panel) rather than from the Photos library, so it copies
/// the original bytes through untouched instead of re-encoding a `UIImage`.
enum PhotoStorage {
    static var photosDirectory: URL {
        let directory = DataStore.appFolder.appendingPathComponent("Photos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    static func url(for fileName: String) -> URL {
        photosDirectory.appendingPathComponent(fileName)
    }

    /// Store only the original. The legacy thumbnail field remains readable
    /// for old libraries, but new previews are generated in memory.
    static func save(source: URL, directory: URL = photosDirectory) throws -> (fileName: String, thumbnailFileName: String) {
        let id = UUID().uuidString
        let ext = source.pathExtension.isEmpty ? "jpg" : source.pathExtension
        let fileName = "\(id).\(ext)"
        try FileManager.default.copyItem(at: source, to: directory.appendingPathComponent(fileName))
        return (fileName, "")
    }

    static func delete(fileName: String, directory: URL = photosDirectory) {
        // Metadata is data, not a trusted path. Never follow a path or symlink
        // supplied by a modified library outside its own photo directory.
        guard !fileName.isEmpty, fileName != ".", fileName != "..",
              URL(fileURLWithPath: fileName).lastPathComponent == fileName else { return }
        let target = directory.appendingPathComponent(fileName)
        guard (try? target.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true,
              target.resolvingSymlinksInPath().deletingLastPathComponent() == directory.resolvingSymlinksInPath() else { return }
        try? FileManager.default.removeItem(at: target)
    }

    /// Thumbnail if one exists, else the original — so a photo imported before
    /// thumbnailing worked still shows something.
    static func displayURL(for photo: Photo) -> URL {
        let thumb = url(for: photo.thumbnailFileName)
        if !photo.thumbnailFileName.isEmpty, FileManager.default.fileExists(atPath: thumb.path) {
            return thumb
        }
        return url(for: photo.fileName)
    }

    private static let previews: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 200
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    static func preview(for photo: Photo) -> NSImage? {
        let source = displayURL(for: photo)
        let key = source.path as NSString
        if let cached = previews.object(forKey: key) { return cached }
        guard let data = ImageThumbnailer.makeThumbnailData(from: source),
              let image = NSImage(data: data) else { return nil }
        previews.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * 4))
        return image
    }

    /// Remove only a known generated thumbnail with a readable original.
    /// Never delete an original, unknown file, symlink, or the only readable copy.
    static func removeLegacyThumbnails(for photos: [Photo], directory: URL) -> Set<String> {
        let originals = Set(photos.map(\.fileName))
        var cleared: Set<String> = []
        for photo in photos {
            let name = photo.thumbnailFileName
            let original = directory.appendingPathComponent(photo.fileName)
            let thumbnail = directory.appendingPathComponent(name)
            guard !name.isEmpty, !originals.contains(name),
                  URL(fileURLWithPath: photo.fileName).lastPathComponent == photo.fileName,
                  URL(fileURLWithPath: name).lastPathComponent == name,
                  name == original.deletingPathExtension().lastPathComponent + "_thumb.jpg",
                  (try? original.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])).map({ $0.isRegularFile == true && $0.isSymbolicLink != true }) == true,
                  ImageThumbnailer.makeThumbnailData(from: original, maxDimension: 1) != nil else { continue }
            do {
                if FileManager.default.fileExists(atPath: thumbnail.path) {
                    let values = try thumbnail.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                    guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
                    try FileManager.default.removeItem(at: thumbnail)
                }
                cleared.insert(name)
            } catch {
                // Keep the legacy reference and retry on the next launch.
            }
        }
        return cleared
    }
}

enum ImageThumbnailer {
    /// Downsamples with ImageIO rather than decoding the full image into an
    /// `NSImage` first — a folder of 40MP photos would otherwise spike memory
    /// hard during a bulk drag-and-drop import.
    static func makeThumbnailData(from source: URL, maxDimension: Int = 640) -> Data? {
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, thumbnail, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
