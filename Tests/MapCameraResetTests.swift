import XCTest
import MapKit
@testable import Waymark

final class MapCameraResetTests: XCTestCase {
    @MainActor
    func testRepeatedOverviewRequestsAreDistinctAndBothReachNativeMap() async {
        let map = RecordingMapView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let anchor = NSView()
        map.addSubview(anchor)
        let accessor = MapViewAccessor()
        accessor.anchor = anchor
        let overview = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 31, longitude: 121),
            span: MKCoordinateSpan(latitudeDelta: 0.8, longitudeDelta: 0.8)
        )
        let firstClick = MapCameraResetRequest(region: overview)
        let secondClick = MapCameraResetRequest(region: overview)
        XCTAssertNotEqual(firstClick.id, secondClick.id)
        map.receivedRegions = []
        XCTAssertTrue(accessor.resetCamera(firstClick, animated: false))

        // Native zoom/pan changes the viewport without changing our command.
        var zoomed = overview
        zoomed.center.latitude += 0.2
        zoomed.span.latitudeDelta /= 4
        map.setRegion(zoomed, animated: false)
        XCTAssertTrue(accessor.resetCamera(secondClick, animated: false))
        XCTAssertEqual(map.receivedRegions.count, 3)
        XCTAssertEqual(map.receivedRegions.last?.center.latitude, overview.center.latitude)
        XCTAssertEqual(map.receivedRegions.last?.span.latitudeDelta, overview.span.latitudeDelta)
    }

    @MainActor
    func testMissingMapFailsSafelyWithoutRetainingAnOldView() async {
        let accessor = MapViewAccessor()
        let request = MapCameraResetRequest(region: MKCoordinateRegion())
        XCTAssertFalse(accessor.resetCamera(request))
        var anchor: NSView? = NSView()
        accessor.anchor = anchor
        anchor = nil
        XCTAssertNil(accessor.anchor)
        XCTAssertFalse(accessor.resetCamera(request))
    }
}

@MainActor
private final class RecordingMapView: MKMapView {
    var receivedRegions: [MKCoordinateRegion] = []

    override func setRegion(_ region: MKCoordinateRegion, animated: Bool) {
        receivedRegions.append(region)
    }
}
