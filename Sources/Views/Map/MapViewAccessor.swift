import SwiftUI
import MapKit

/// A command, not a selection value: asking for the same region twice must
/// still move a map that has been manipulated in between.
struct MapCameraResetRequest: Identifiable {
    let id = UUID()
    let region: MKCoordinateRegion
}

/// A narrow bridge to this SwiftUI map's native view. It neither replaces
/// MapKit's delegate nor owns selection or persistent camera state.
@MainActor
final class MapViewAccessor {
    weak var anchor: NSView?

    var mapView: MKMapView? {
        var ancestor = anchor?.superview
        while let view = ancestor {
            if let map = findMap(in: view) { return map }
            ancestor = view.superview
        }
        return nil
    }

    @discardableResult
    func resetCamera(_ request: MapCameraResetRequest, animated: Bool = true) -> Bool {
        guard let map = mapView else { return false }
        // Always execute the command, even if SwiftUI's position binding still
        // contains the same requested region after a native map gesture.
        map.setRegion(request.region, animated: animated)
        return true
    }

    private func findMap(in view: NSView) -> MKMapView? {
        if let map = view as? MKMapView { return map }
        return view.subviews.lazy.compactMap { self.findMap(in: $0) }.first
    }
}

struct MapViewAnchor: NSViewRepresentable {
    let accessor: MapViewAccessor

    func makeNSView(context: Context) -> NSView {
        let view = PassthroughView()
        accessor.anchor = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        accessor.anchor = nsView
    }

    private final class PassthroughView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
