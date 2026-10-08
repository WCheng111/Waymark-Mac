import XCTest
@testable import Waymark

final class DemoLibraryTests: XCTestCase {
    func testFictionalPlacesHaveStableIDsAndFourCities() {
        let first = DemoLibrary.makePlaces()
        let second = DemoLibrary.makePlaces()
        XCTAssertEqual(first.count, 10)
        XCTAssertEqual(Set(first.map(\.city)), ["Porto", "Coimbra", "Lisbon", "Sintra"])
        XCTAssertEqual(first.map(\.id), second.map(\.id))
        XCTAssertTrue(first.allSatisfy { $0.visits.count == 1 && $0.visits[0].note.contains("Fictional demo") })
        XCTAssertTrue(first.allSatisfy { $0.photos.isEmpty && $0.longitude < 0 })
    }

    func testSeedIsIsolatedAndDoesNotOverwriteExistingData() throws {
        let fm = FileManager.default
        let temporary = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: temporary) }
        let assets = temporary.appendingPathComponent("assets")
        let library = temporary.appendingPathComponent("demo")
        try fm.createDirectory(at: assets, withIntermediateDirectories: true)
        for name in ["coast", "garden", "lake"] {
            try Data("synthetic-test-image".utf8).write(to: assets.appendingPathComponent(name + ".png"))
        }
        try DemoLibrary.prepare(at: library, assets: assets)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try Data(contentsOf: library.appendingPathComponent("data.json"))
        let places = try decoder.decode([Place].self, from: data)
        XCTAssertEqual(places.flatMap(\.photos).count, 30)
        XCTAssertEqual(Set(places.flatMap(\.photos).map(\.fileName)).count, 30)
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: library.appendingPathComponent("Photos").path).count, 30)
        try DemoLibrary.prepare(at: library, assets: nil)
        XCTAssertEqual(try Data(contentsOf: library.appendingPathComponent("data.json")), data)
        let store = DataStore(storageFolder: library)
        XCTAssertEqual(store.trips.count, 2)
    }
}
