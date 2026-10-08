import XCTest
import MapKit
@testable import Waymark

final class CitySynchronizationTests: XCTestCase {
    private var folder: URL!
    private var store: DataStore!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("Waymark-city-tests-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        store = DataStore(storageFolder: folder)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: folder)
    }

    private func place(_ city: String, name: String = "测试地点") -> Place {
        Place(name: name, city: city, country: "测试地区", latitude: 10.12345, longitude: 20.54321)
    }

    func testFirstCheckInAddsCityAndPersistsChosenClassification() {
        XCTAssertTrue(store.needsCityClassification("长沙"))
        store.add(place("长沙"), cityKind: .resident)
        XCTAssertEqual(store.cityNames, ["长沙"])
        XCTAssertEqual(store.cityAggregates(ofKind: .resident).count, 1)
        XCTAssertFalse(store.needsCityClassification("长沙"))
        let reloaded = DataStore(storageFolder: folder)
        XCTAssertEqual(reloaded.cityNames, ["长沙"])
        XCTAssertEqual(reloaded.kind(forCity: "长沙"), .resident)
    }

    func testExistingCityIsReusedAndCountsRefresh() {
        store.add(place("长沙"), cityKind: .travel)
        let before = store.cityAggregates[0]
        store.add(place(" 长沙市\n", name: "另一个地点"))
        let after = store.cityAggregates[0]
        XCTAssertEqual(store.cityNames, ["长沙"])
        XCTAssertEqual(after.placeCount, 2)
        XCTAssertNotEqual(before, after)
        XCTAssertFalse(store.needsCityClassification("长沙市"))
        XCTAssertEqual(store.kind(forCity: "长沙"), .travel)
    }

    func testCityTotalsAndSidebarGroupsShareExactlyTheSameCities() {
        store.add(place("武汉"), cityKind: .resident)
        store.add(place("长沙"), cityKind: .travel)
        store.add(place("长沙", name: "测试景点甲"))
        let grouped = CityKind.allCases.flatMap { store.cityAggregates(ofKind: $0) }
        XCTAssertEqual(Set(grouped.map(\.city)), Set(store.places.map(\.city)))
        XCTAssertEqual(grouped.count, store.cityNames.count)
        XCTAssertEqual(grouped.reduce(0) { $0 + $1.placeCount }, store.places.count)
    }

    func testReassigningAnExistingPlaceUpdatesBothCitiesWithoutLosingVisits() {
        var original = place("武汉", name: "测试景点甲")
        original.visits = [Visit(date: Date(), note: "保留备注")]
        store.add(original, cityKind: .resident)
        var corrected = original
        corrected.city = "长沙"
        store.setKind(.travel, forCity: "长沙")
        store.update(corrected)
        XCTAssertEqual(store.cityNames, ["长沙"])
        XCTAssertEqual(store.places.count, 1)
        XCTAssertEqual(store.place(id: original.id)?.visits, original.visits)
    }

    func testUnclassifiedExistingCityStillRequestsAChoice() {
        store.add(place("长沙"))
        XCTAssertTrue(store.needsCityClassification("长沙"))
        XCTAssertEqual(store.cityAggregates(ofKind: .travel).count, 1)
        XCTAssertFalse(store.needsCityClassification(" \n"))
    }

    func testChineseGeocoderCitySuffixIsNormalized() {
        let placemark = MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: 10.12345, longitude: 20.54321),
            addressDictionary: ["City": "长沙市", "CountryCode": "CN", "Country": "中国"]
        )
        XCTAssertEqual(ReverseGeocodingService.cityName(for: placemark), "长沙")
    }
}
