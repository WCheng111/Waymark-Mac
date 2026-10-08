import XCTest
@testable import Waymark

final class PhotoBatchDateTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private var chosenDate: Date {
        calendar.date(from: DateComponents(year: 2023, month: 4, day: 16, hour: 15))!
    }

    func testBatchDateUpdatesEveryDraftWithoutChangingMetadataOrIdentity() {
        var drafts = (0..<12).map { index in
            ImportedPhotoDraft(
                sourceURL: URL(fileURLWithPath: "/tmp/photo-\(index).jpg"),
                capturedDate: Date(timeIntervalSince1970: Double(index) * 86_400),
                latitude: 30.2, longitude: 120.1, caption: "照片 \(index)"
            )
        }
        let original = drafts
        PhotoImportService.applyCaptureDate(chosenDate, to: &drafts, calendar: calendar)
        XCTAssertEqual(drafts.count, original.count)
        for (before, after) in zip(original, drafts) {
            XCTAssertEqual(after.capturedDate, calendar.startOfDay(for: chosenDate))
            XCTAssertEqual(after.id, before.id)
            XCTAssertEqual(after.sourceURL, before.sourceURL)
            XCTAssertEqual(after.latitude, before.latitude)
            XCTAssertEqual(after.longitude, before.longitude)
            XCTAssertEqual(after.caption, before.caption)
        }
        // The import snapshot and per-card edits remain independent.
        drafts[0].capturedDate = chosenDate.addingTimeInterval(86_400)
        XCTAssertNotEqual(drafts[0].capturedDate, drafts[1].capturedDate)
        XCTAssertEqual(original[0].capturedDate, Date(timeIntervalSince1970: 0))
    }

    func testEmptyBatchAndRepeatedApplication() {
        var drafts: [ImportedPhotoDraft] = []
        PhotoImportService.applyCaptureDate(chosenDate, to: &drafts, calendar: calendar)
        XCTAssertTrue(drafts.isEmpty)
        drafts.append(ImportedPhotoDraft(sourceURL: URL(fileURLWithPath: "/tmp/one.png"), capturedDate: Date()))
        PhotoImportService.applyCaptureDate(chosenDate, to: &drafts, calendar: calendar)
        let nextDay = chosenDate.addingTimeInterval(86_400)
        PhotoImportService.applyCaptureDate(nextDay, to: &drafts, calendar: calendar)
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: drafts[0].capturedDate),
                       DateComponents(year: 2023, month: 4, day: 17))
    }
}
