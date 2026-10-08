import XCTest
import AppKit
import ImageIO
import UniformTypeIdentifiers
@testable import Waymark

final class PhotoClipboardTests: XCTestCase {
    private func imageData(_ type: UTType = .png) throws -> Data {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let image = try XCTUnwrap(context.makeImage())
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2020:01:02 03:04:05"]
        ] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @MainActor
    func testEmptyTextAndRemoteURLDoNotBecomePhotos() async throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        XCTAssertTrue(try PhotoClipboardService.makeDrafts(from: board).isEmpty)
        board.setString("ordinary text", forType: .string)
        XCTAssertTrue(try PhotoClipboardService.makeDrafts(from: board).isEmpty)
        board.clearContents()
        board.setString("https://example.invalid/photo.png", forType: .fileURL)
        XCTAssertTrue(try PhotoClipboardService.makeDrafts(from: board).isEmpty)
    }

    @MainActor
    func testOneImageWithMultipleRepresentationsProducesOneDraft() async throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let png = try imageData()
        let item = NSPasteboardItem()
        item.setData(png, forType: .png)
        item.setData(try imageData(.tiff), forType: .tiff)
        board.writeObjects([item])
        let drafts = try PhotoClipboardService.makeDrafts(from: board)
        XCTAssertEqual(drafts.count, 1)
        let draft = try XCTUnwrap(drafts.first)
        XCTAssertNotNil(draft.temporarySource)
        XCTAssertEqual(try Data(contentsOf: draft.sourceURL), png)
        XCTAssertEqual(draft.sourceURL.pathExtension, "png")
    }

    @MainActor
    func testCopiedFilesTakePriorityOverPreviewsAndKeepMetadata() async throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Waymark-clipboard-test-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let urls = [folder.appendingPathComponent("one.jpg"), folder.appendingPathComponent("two.jpg")]
        for url in urls { try imageData(.jpeg).write(to: url) }
        let items = try urls.map { url in
            let item = NSPasteboardItem()
            item.setString(url.absoluteString, forType: .fileURL)
            item.setData(try imageData(), forType: .png)
            return item
        }
        board.writeObjects(items)
        let drafts = try PhotoClipboardService.makeDrafts(from: board)
        XCTAssertEqual(drafts.map(\.sourceURL), urls)
        XCTAssertTrue(drafts.allSatisfy { $0.temporarySource == nil })
        XCTAssertEqual(Calendar.current.component(.year, from: try XCTUnwrap(drafts.first).capturedDate), 2020)
        XCTAssertTrue(urls.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
    }

    @MainActor
    func testStagedFilesLiveThroughSnapshotThenAreCleanedUp() async throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setData(try imageData(), forType: .png)
        var drafts = try PhotoClipboardService.makeDrafts(from: board)
        let url = try XCTUnwrap(drafts.first?.sourceURL)
        var snapshot = drafts
        drafts = []
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(snapshot.count, 1)
        snapshot = []
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
    }

    @MainActor
    func testPastedImageCanBeImportedWithThumbnailAndPersisted() async throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let png = try imageData()
        board.setData(png, forType: .png)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Waymark-paste-import-test-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var drafts = try PhotoClipboardService.makeDrafts(from: board)
        let batchDate = Date(timeIntervalSince1970: 1_681_617_600)
        PhotoImportService.applyCaptureDate(batchDate, to: &drafts)
        let photo = try PhotoImportService.makePhoto(from: XCTUnwrap(drafts.first), storageDirectory: folder)
        drafts = []
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent(photo.fileName)), png)
        XCTAssertTrue(photo.thumbnailFileName.isEmpty)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), [photo.fileName])
        XCTAssertNotNil(ImageThumbnailer.makeThumbnailData(from: folder.appendingPathComponent(photo.fileName)))
        let store = DataStore(storageFolder: folder)
        let place = Place(name: "测试", city: "杭州", country: "中国", latitude: 30, longitude: 120)
        store.add(place, cityKind: .travel)
        store.addPhotos([photo], toPlace: place.id)
        let saved = try XCTUnwrap(DataStore(storageFolder: folder).place(id: place.id)?.photos)
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.capturedDate, Calendar.current.startOfDay(for: batchDate))
    }

    @MainActor
    func testCorruptImageIsIgnoredWithoutDiscardingValidItems() async throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let invalid = NSPasteboardItem()
        invalid.setData(Data("not an image".utf8), forType: .png)
        let valid = NSPasteboardItem()
        valid.setData(try imageData(.tiff), forType: .tiff)
        board.writeObjects([invalid, valid])
        let drafts = try PhotoClipboardService.makeDrafts(from: board)
        XCTAssertEqual(drafts.count, 1)
        XCTAssertNotNil(NSImage(contentsOf: try XCTUnwrap(drafts.first?.sourceURL)))
    }
}
