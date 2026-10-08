import SwiftUI
import MapKit

/// MapKit's feature-selection API is unavailable on macOS. Read the labels
/// exposed by our own map's public AppKit accessibility surface instead.
/// This does not inspect other apps or require Accessibility permission.
@MainActor
final class MapLabelReader {
    let mapAccessor: MapViewAccessor

    init(mapAccessor: MapViewAccessor) {
        self.mapAccessor = mapAccessor
    }

    struct Selection {
        let name: String
        let coordinate: CLLocationCoordinate2D
    }

    func selection(at point: CGPoint) -> Selection? {
        guard let anchor = mapAccessor.anchor, let window = anchor.window,
              let map = mapAccessor.mapView else { return nil }
        let local = NSPoint(x: point.x, y: anchor.isFlipped ? point.y : anchor.bounds.height - point.y)
        let screenPoint = window.convertPoint(toScreen: anchor.convert(local, to: nil))
        // Hit-testing also resolves clicks on the text beside a POI icon.
        // Do not choose the nearest label: an empty-map click must stay unnamed.
        guard let hit = map.accessibilityHitTest(screenPoint) as? NSObject,
              !(hit is NSView),
              let label = labelDetails(hit) else { return nil }

        // Accessibility bounds describe the POI icon, even when its text was
        // clicked. Use that location instead of the offset text's coordinate.
        let center = NSPoint(x: label.frame.midX, y: label.frame.midY)
        let mapPoint = map.convert(window.convertPoint(fromScreen: center), from: nil)
        guard map.bounds.contains(mapPoint) else { return nil }
        return Selection(name: label.name, coordinate: map.convert(mapPoint, toCoordinateFrom: map))
    }

    private func labelDetails(_ object: NSObject) -> (name: String, frame: NSRect)? {
        // MapKit's base-map labels still implement the legacy public attribute
        // API, not NSAccessibilityProtocol. Keep this compatibility path local.
        guard object.accessibilityAttributeValue(.role) as? String == NSAccessibility.Role.button.rawValue,
              let title = object.accessibilityAttributeValue(.title) as? String,
              let position = object.accessibilityAttributeValue(.position) as? NSValue,
              let size = object.accessibilityAttributeValue(.size) as? NSValue else { return nil }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let frame = NSRect(origin: position.pointValue, size: size.sizeValue)
        guard !name.isEmpty, !frame.isEmpty else { return nil }
        return (name, frame)
    }

}
