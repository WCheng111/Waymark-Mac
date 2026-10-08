import XCTest
@testable import Waymark

final class VisitReflectionsTests: XCTestCase {
    private func fixture(_ body: (DataStore, Place, URL) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Waymark-visit-feelings-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = DataStore(storageFolder: folder)
        var place = Place(name: "测试公园", city: "上海", latitude: 31, longitude: 121, notes: "旧版感受")
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        place.visits = [Visit(date: date, note: "第一次"), Visit(date: date, note: "第二次")]
        store.add(place)
        try body(store, place, folder)
    }

    func testSameDayVisitsKeepIndependentFeelingsAfterReload() throws {
        try fixture { store, place, folder in
            try store.updateVisitFeeling("晴天散步", visitID: place.visits[0].id, placeID: place.id)
            try store.updateVisitFeeling("雨中再访", visitID: place.visits[1].id, placeID: place.id)
            let reloaded = DataStore(storageFolder: folder)
            let saved = try XCTUnwrap(reloaded.place(id: place.id))
            XCTAssertEqual(saved.visits.map(\.note), ["晴天散步", "雨中再访"])
            XCTAssertEqual(saved.visits.map(\.id), place.visits.map(\.id))
            XCTAssertEqual(saved.visits.map(\.date), place.visits.map(\.date))
            XCTAssertEqual(saved.notes, "旧版感受")
            XCTAssertEqual(saved.reflectionVisit(preferredID: place.visits[1].id)?.note, "雨中再访")
            reloaded.addVisit(Visit(), toPlace: place.id)
            XCTAssertEqual(reloaded.place(id: place.id)?.visits.last?.note, "")
            try reloaded.updateVisitFeeling("", visitID: place.visits[0].id, placeID: place.id)
            XCTAssertEqual(reloaded.place(id: place.id)?.visits[1].note, "雨中再访")
            try reloaded.updateVisitFeeling("错误", visitID: UUID(), placeID: place.id)
            XCTAssertEqual(reloaded.place(id: place.id)?.visits[0].note, "")
        }
    }

    func testLegacyNotesArePreservedUntilExplicitAssignmentAndNotDuplicated() throws {
        try fixture { store, place, folder in
            XCTAssertEqual(DataStore(storageFolder: folder).place(id: place.id)?.notes, "旧版感受")
            try store.assignLegacyFeeling(toVisit: UUID(), placeID: place.id)
            XCTAssertEqual(store.place(id: place.id)?.notes, "旧版感受")
            try store.assignLegacyFeeling(toVisit: place.visits[1].id, placeID: place.id)
            try store.assignLegacyFeeling(toVisit: place.visits[1].id, placeID: place.id)
            let saved = try XCTUnwrap(DataStore(storageFolder: folder).place(id: place.id))
            XCTAssertEqual(saved.notes, "")
            XCTAssertEqual(saved.visits[0].note, "第一次")
            XCTAssertEqual(saved.visits[1].note, "第二次\n\n旧版感受")
        }
    }

    func testSelectionFallsBackAndDeletedVisitCannotBeEdited() throws {
        try fixture { store, original, _ in
            var place = original
            place.visits[1].date = place.visits[0].date.addingTimeInterval(86_400)
            store.update(place)
            XCTAssertEqual(place.reflectionVisit(preferredID: nil)?.id, place.visits[1].id)
            XCTAssertEqual(place.reflectionVisit(preferredID: UUID())?.id, place.visits[1].id)
            store.deleteVisit(id: place.visits[1].id, fromPlace: place.id)
            try store.updateVisitFeeling("不能写到其他记录", visitID: place.visits[1].id, placeID: place.id)
            XCTAssertEqual(store.place(id: place.id)?.reflectionVisit(preferredID: place.visits[1].id)?.note, "第一次")
            store.deleteVisit(id: place.visits[0].id, fromPlace: place.id)
            XCTAssertNil(store.place(id: place.id)?.reflectionVisit(preferredID: nil))
            XCTAssertEqual(store.place(id: place.id)?.notes, "旧版感受")
        }
    }

    func testFailedSavePreservesLegacyAndVisitFeelings() throws {
        try fixture { store, place, folder in
            let url = folder.appendingPathComponent("data.json")
            try FileManager.default.removeItem(at: url)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try Data("block".utf8).write(to: url.appendingPathComponent("obstacle"))
            XCTAssertThrowsError(try store.updateVisitFeeling("新内容", visitID: place.visits[0].id, placeID: place.id))
            XCTAssertThrowsError(try store.assignLegacyFeeling(toVisit: place.visits[0].id, placeID: place.id))
            XCTAssertEqual(store.place(id: place.id), place)
        }
    }
}
