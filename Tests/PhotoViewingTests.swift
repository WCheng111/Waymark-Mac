import XCTest
import AppKit
import ImageIO
import UniformTypeIdentifiers
@testable import Waymark

final class PhotoViewingTests: XCTestCase {
    func testDeletionRejectsTraversalAndSymlinks() throws {
        try withFolder { folder in
            let library = folder.appendingPathComponent("Photos", isDirectory: true)
            try FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
            let outside = folder.appendingPathComponent("outside.png")
            try Data("outside".utf8).write(to: outside)
            let inside = library.appendingPathComponent("inside.png")
            try Data("inside".utf8).write(to: inside)
            let link = library.appendingPathComponent("link.png")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
            for name in ["../outside.png", outside.path, ".", "..", "", "link.png"] {
                PhotoStorage.delete(fileName: name, directory: library)
            }
            XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: link.path))
            PhotoStorage.delete(fileName: "inside.png", directory: library)
            XCTAssertFalse(FileManager.default.fileExists(atPath: inside.path))
        }
    }

    private func withFolder(_ body: (URL) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Waymark-view-test-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try body(folder)
    }

    private func writeImage(to url: URL) throws {
        let context = try XCTUnwrap(CGContext(data: nil, width: 120, height: 80, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

    func testSingleFileImportPreservesBytesAndGeneratesPreviewWithoutDiskCopy() throws {
        try withFolder { folder in
            let source = folder.appendingPathComponent("source.png")
            try writeImage(to: source)
            let library = folder.appendingPathComponent("Photos")
            try FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
            let saved = try PhotoStorage.save(source: source, directory: library)
            XCTAssertEqual(saved.thumbnailFileName, "")
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: library.path), [saved.fileName])
            XCTAssertEqual(try Data(contentsOf: source), try Data(contentsOf: library.appendingPathComponent(saved.fileName)))
            XCTAssertNotNil(ImageThumbnailer.makeThumbnailData(from: library.appendingPathComponent(saved.fileName)))
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: library.path).count, 1)
        }
    }

    func testCleanupRemovesOnlyKnownRecoverableThumbnailsAndIsIdempotent() throws {
        try withFolder { folder in
            let original = folder.appendingPathComponent("valid.png")
            try writeImage(to: original)
            let bytes = try Data(contentsOf: original)
            try bytes.write(to: folder.appendingPathComponent("valid_thumb.jpg"))
            try bytes.write(to: folder.appendingPathComponent("missing_thumb.jpg"))
            try bytes.write(to: folder.appendingPathComponent("unknown.jpg"))
            let photos = [
                Photo(fileName: "valid.png", thumbnailFileName: "valid_thumb.jpg", capturedDate: Date()),
                Photo(fileName: "missing.png", thumbnailFileName: "missing_thumb.jpg", capturedDate: Date()),
                Photo(fileName: "valid.png", thumbnailFileName: "unknown.jpg", capturedDate: Date()),
                Photo(fileName: "valid.png", thumbnailFileName: "valid.png", capturedDate: Date())
            ]
            XCTAssertEqual(PhotoStorage.removeLegacyThumbnails(for: photos, directory: folder), ["valid_thumb.jpg"])
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("valid_thumb.jpg").path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("missing_thumb.jpg").path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("unknown.jpg").path))
            XCTAssertEqual(try Data(contentsOf: original), bytes)
            XCTAssertEqual(PhotoStorage.removeLegacyThumbnails(for: photos, directory: folder), ["valid_thumb.jpg"])
        }
    }

    func testLegacyPhotoDecodesAndRotationPersistsWithoutChangingOtherFields() throws {
        try withFolder { folder in
            let photo = Photo(fileName: "original.png", thumbnailFileName: "", capturedDate: Date(timeIntervalSince1970: 123456), caption: "保留说明")
            let legacyData = try JSONEncoder().encode(photo)
            XCTAssertFalse(String(decoding: legacyData, as: UTF8.self).contains("rotationQuarterTurns"))
            XCTAssertEqual(try JSONDecoder().decode(Photo.self, from: legacyData).displayQuarterTurns, 0)
            let store = DataStore(storageFolder: folder)
            var place = Place(name: "测试", city: "杭州", country: "中国", latitude: 30, longitude: 120)
            place.photos = [photo]
            store.add(place)
            store.rotatePhoto(quarterTurns: -1, photoID: photo.id, placeID: place.id)
            var saved = try XCTUnwrap(DataStore(storageFolder: folder).place(id: place.id)?.photos.first)
            XCTAssertEqual(saved.displayQuarterTurns, 3)
            saved.rotationQuarterTurns = nil
            // importedAt may lose subseconds in existing ISO8601 persistence.
            XCTAssertEqual(saved.fileName, photo.fileName)
            XCTAssertEqual(saved.capturedDate, photo.capturedDate)
            XCTAssertEqual(saved.id, photo.id)
            XCTAssertEqual(saved.caption, photo.caption)
            store.rotatePhoto(quarterTurns: 4, photoID: photo.id, placeID: place.id)
            XCTAssertEqual(store.place(id: place.id)?.photos.first?.displayQuarterTurns, 0)
        }
    }

    func testRotatedPhotoFitsViewportAndPanIsBounded() {
        let viewport = CGSize(width: 800, height: 500)
        let fitted = PhotoViewportGeometry.fittedSize(image: CGSize(width: 1200, height: 800), viewport: viewport, quarterTurns: 1)
        XCTAssertLessThanOrEqual(fitted.width, viewport.height)
        XCTAssertLessThanOrEqual(fitted.height, viewport.width)
        XCTAssertEqual(PhotoViewportGeometry.clampedOffset(CGSize(width: 9999, height: 9999), image: fitted, viewport: viewport, quarterTurns: 1, zoom: 1), .zero)
        let offset = PhotoViewportGeometry.clampedOffset(CGSize(width: 9999, height: -9999), image: fitted, viewport: viewport, quarterTurns: 1, zoom: 4)
        XCTAssertEqual(offset.width, max(0, (fitted.height * 4 - viewport.width) / 2), accuracy: 0.001)
        XCTAssertEqual(offset.height, -(fitted.width * 4 - viewport.height) / 2, accuracy: 0.001)
    }

    func testViewerRequestKeepsSelectionOrderAndReadsCurrentRecords() throws {
        try withFolder { folder in
            let store = DataStore(storageFolder: folder)
            var place = Place(name: "测试", city: "杭州", country: "中国", latitude: 30, longitude: 120)
            let first = Photo(fileName: "first.png", thumbnailFileName: "", capturedDate: Date())
            let second = Photo(fileName: "second.png", thumbnailFileName: "", capturedDate: Date())
            place.photos = [first, second]
            store.add(place)
            let request = try XCTUnwrap(PhotoViewerRequest(placeID: place.id, photos: [second, first], index: 1))
            let restored = try JSONDecoder().decode(PhotoViewerRequest.self, from: JSONEncoder().encode(request))
            XCTAssertEqual(request, restored)
            XCTAssertEqual(restored.selectedPhotoID, first.id)
            XCTAssertEqual(restored.photos(in: store).map(\.id), [second.id, first.id])
            store.rotatePhoto(quarterTurns: 1, photoID: first.id, placeID: place.id)
            XCTAssertEqual(restored.photos(in: store).last?.displayQuarterTurns, 1)
            place.photos = [second]
            store.update(place)
            XCTAssertEqual(restored.photos(in: store).map(\.id), [second.id])
            XCTAssertNil(PhotoViewerRequest(placeID: place.id, photos: [], index: 0))
            XCTAssertNil(PhotoViewerRequest(placeID: place.id, photos: [second], index: -1))
        }
    }

    func testImageFitsIndependentlyResizedWindow() {
        for viewport in [CGSize(width: 640, height: 300), CGSize(width: 700, height: 900), CGSize(width: 1600, height: 450)] {
            for turns in 0..<4 {
                let size = PhotoViewportGeometry.fittedSize(image: CGSize(width: 1200, height: 800), viewport: viewport, quarterTurns: turns)
                XCTAssertLessThanOrEqual(turns % 2 == 0 ? size.width : size.height, viewport.width)
                XCTAssertLessThanOrEqual(turns % 2 == 0 ? size.height : size.width, viewport.height)
            }
        }
    }
}
