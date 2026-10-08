import XCTest
@testable import Waymark

final class PhotoBatchEditingTests: XCTestCase {
    private func fixture(_ body: (DataStore, Place, Place, URL) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Waymark-batch-edit-\(UUID())")
        let photosFolder = folder.appendingPathComponent("Photos")
        try FileManager.default.createDirectory(at: photosFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = DataStore(storageFolder: folder)
        var place = Place(name: "测试西湖", city: "杭州", country: "中国", latitude: 30, longitude: 120)
        for index in 0..<3 {
            var photo = Photo(fileName: "\(index).jpg", thumbnailFileName: "", capturedDate: Date(timeIntervalSince1970: Double(index) * 86_400), caption: "说明 \(index)")
            photo.rotationQuarterTurns = 1
            place.photos.append(photo)
            try Data("original \(index)".utf8).write(to: photosFolder.appendingPathComponent(photo.fileName))
        }
        var other = Place(name: "其他地点", city: "北京", country: "中国", latitude: 40, longitude: 116)
        other.photos = [Photo(fileName: "other.jpg", thumbnailFileName: "", capturedDate: Date(timeIntervalSince1970: 0))]
        try Data("other".utf8).write(to: photosFolder.appendingPathComponent("other.jpg"))
        store.add(place)
        store.add(other)
        try body(store, place, other, folder)
    }

    func testBatchEditsOnlySelectedFieldsAndPhotosAndPersists() throws {
        try fixture { store, place, other, folder in
            let ids = Set(place.photos.prefix(2).map(\.id))
            let date = Date(timeIntervalSince1970: 1_681_617_600)
            try store.updatePhotos(ids: ids, inPlace: place.id, capturedDate: date, caption: nil)
            let saved = try XCTUnwrap(DataStore(storageFolder: folder).place(id: place.id))
            for index in 0..<2 {
                XCTAssertEqual(saved.photos[index].capturedDate, date)
                XCTAssertEqual(saved.photos[index].caption, place.photos[index].caption)
                XCTAssertEqual(saved.photos[index].rotationQuarterTurns, 1)
                XCTAssertEqual(saved.photos[index].fileName, place.photos[index].fileName)
            }
            XCTAssertEqual(saved.photos[2].capturedDate, place.photos[2].capturedDate)
            XCTAssertEqual(store.place(id: other.id)?.photos, other.photos)
            try store.updatePhotos(ids: ids, inPlace: place.id, capturedDate: nil, caption: "")
            XCTAssertTrue(store.place(id: place.id)!.photos.prefix(2).allSatisfy { $0.caption.isEmpty && $0.capturedDate == date })
            XCTAssertEqual(store.place(id: place.id)?.photos[2].caption, "说明 2")
            XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("Photos/0.jpg")), Data("original 0".utf8))
        }
    }

    func testBatchDeleteRemovesOnlySelectedRecordsAndTheirFiles() throws {
        try fixture { store, place, other, folder in
            var ids = Set(place.photos.prefix(2).map(\.id))
            ids.insert(other.photos[0].id) // A foreign ID cannot delete across places.
            try store.deletePhotos(ids: ids, fromPlace: place.id)
            let loaded = DataStore(storageFolder: folder)
            XCTAssertEqual(loaded.place(id: place.id)?.photos.map(\.id), [place.photos[2].id])
            XCTAssertEqual(loaded.place(id: other.id)?.photos.count, 1)
            XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent("Photos").path)), ["2.jpg", "other.jpg"])
            XCTAssertEqual(loaded.places.count, 2)
            try store.deletePhotos(ids: [], fromPlace: place.id)
            XCTAssertEqual(store.photoCount, 2)
        }
    }

    func testFailedSaveDoesNotDeleteFilesOrMutateMemory() throws {
        try fixture { store, place, _, folder in
            let dataURL = folder.appendingPathComponent("data.json")
            try FileManager.default.removeItem(at: dataURL)
            try FileManager.default.createDirectory(at: dataURL, withIntermediateDirectories: true)
            try Data("block replacement".utf8).write(to: dataURL.appendingPathComponent("obstacle"))
            let ids = Set(place.photos.map(\.id))
            XCTAssertThrowsError(try store.deletePhotos(ids: ids, fromPlace: place.id))
            XCTAssertEqual(store.place(id: place.id)?.photos, place.photos)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent("Photos").path).count, 4)
            XCTAssertThrowsError(try store.updatePhotos(ids: ids, inPlace: place.id, capturedDate: Date(), caption: "new"))
            XCTAssertEqual(store.place(id: place.id)?.photos, place.photos)
        }
    }
}
