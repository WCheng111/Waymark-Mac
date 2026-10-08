import SwiftUI
import MapKit
import OSLog

struct MapCanvasView: View {
    @Environment(DataStore.self) private var store

    @Binding var selectedCity: String?
    @Binding var selectedPlaceID: UUID?
    @Binding var cameraPosition: MapCameraPosition
    var cameraResetRequest: MapCameraResetRequest?
    @Binding var showsCoverageGrid: Bool
    @Binding var mapStyleChoice: MapStyleChoice
    /// What the map is actually showing right now. Lifted out of this view so
    /// `ContentView` can reason about the current zoom even while the map is
    /// unmounted behind the photo gallery.
    @Binding var visibleRegion: MKCoordinateRegion?
    /// When set, the map draws that journey's route instead of a city's
    /// coverage grid.
    var selectedTrip: Trip?
    var onFocusStop: (TripStop) -> Void
    var onPlaceCreated: (Place) -> Void

    /// Above this visible latitude span, individual pins would start
    /// overlapping and get expensive to render, so the map switches to one
    /// marker per city instead. Same threshold as the iPhone app.
    private static let cityAggregationSpanThreshold: Double = 1.5

    @State private var pendingCoordinate: PendingCoordinate?
    /// A map click previews a location; only the explicit check-in action
    /// opens the editor. Panning and zooming never commit a place.
    @State private var pickedCoordinate: PendingCoordinate?
    @State private var mapAccessor = MapViewAccessor()
    private var labelReader: MapLabelReader { MapLabelReader(mapAccessor: mapAccessor) }

    /// Places drawn on the map: everything, or just the focused city.
    private var visiblePlaces: [Place] {
        if let selectedTrip { return selectedTrip.places }
        guard let selectedCity else { return store.places }
        return store.places(inCity: selectedCity)
    }

    private var showsCityAggregates: Bool {
        selectedTrip == nil
            && selectedCity == nil
            && (visibleRegion?.span.latitudeDelta ?? 0) > Self.cityAggregationSpanThreshold
    }

    /// The grid is only meaningful scoped to one city — a bounding box drawn
    /// around places on three continents would say nothing about exploration.
    private var coverageSummary: CityCoverageSummary? {
        // A trip spans cities, so a single city's grid would be drawing the
        // wrong thing underneath its route.
        guard selectedTrip == nil, let selectedCity else { return nil }
        return store.coverageSummary(forCity: selectedCity)
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                if showsCoverageGrid, let coverageSummary {
                    // Highlight explored cells while leaving the rest of the
                    // base map unobscured.
                    ForEach(coverageSummary.visitedCells) { cell in
                        MapPolygon(coordinates: cell.corners)
                            .foregroundStyle(CoveragePalette.visitedFill)
                            .stroke(CoveragePalette.visitedStroke, lineWidth: 1.5)
                    }
                }

                if let selectedTrip {
                    // Dashed, so it reads as "the order I went" rather than a
                    // road you could drive.
                    MapPolyline(coordinates: selectedTrip.coordinates)
                        .stroke(
                            TripPalette.route.opacity(0.85),
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round, dash: [10, 7])
                        )
                }

                if showsCityAggregates {
                    ForEach(store.cityAggregates) { aggregate in
                        Annotation(aggregate.city, coordinate: aggregate.coordinate) {
                            CityAggregatePinView(aggregate: aggregate)
                                .onTapGesture {
                                    pickedCoordinate = nil
                                    focus(city: aggregate.city)
                                }
                        }
                        .annotationTitles(.hidden)
                    }
                    ForEach(store.places.filter { $0.city.isEmpty }) { place in
                        placeAnnotation(place)
                    }
                } else {
                    ForEach(visiblePlaces) { place in
                        placeAnnotation(place)
                    }
                }

                // Drawn after the place pins so the numbers stay on top.
                if let selectedTrip {
                    ForEach(selectedTrip.stops) { stop in
                        Annotation(stop.city, coordinate: stop.coordinate) {
                            TripStopPinView(stop: stop)
                                .onTapGesture {
                                    pickedCoordinate = nil
                                    onFocusStop(stop)
                                }
                        }
                        .annotationTitles(.hidden)
                    }
                }

                if let pickedCoordinate {
                    Annotation("待打卡位置", coordinate: pickedCoordinate.coordinate, anchor: .bottom) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 36))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                            .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                            .accessibilityLabel("待打卡位置")
                            .allowsHitTesting(false)
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(mapStyleChoice.mapStyle)
            .background(MapViewAnchor(accessor: mapAccessor))
            .mapControls {
                MapCompass()
                MapZoomStepper()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
            }
            // Attach the tap to the map, before the overlays, so the check-in
            // card and other controls don't also move the picked coordinate.
            // Child annotation gestures keep opening their existing details.
            .simultaneousGesture(
                SpatialTapGesture(count: 2)
                    .exclusively(before: SpatialTapGesture())
                    .onEnded { result in
                        guard pendingCoordinate == nil else { return }
                        switch result {
                        case .first(let tap):
                            // Own the double-click too: a SwiftUI tap recognizer
                            // can otherwise prevent MapKit's native double-click.
                            guard let coordinate = proxy.convert(tap.location, from: .local),
                                  let region = visibleRegion else { return }
                            pickedCoordinate = nil
                            withAnimation(.easeInOut) {
                                cameraPosition = .region(MKCoordinateRegion(
                                    center: coordinate,
                                    span: MKCoordinateSpan(
                                        latitudeDelta: max(region.span.latitudeDelta * 0.5, 0.0005),
                                        longitudeDelta: max(region.span.longitudeDelta * 0.5, 0.0005)
                                    )
                                ))
                            }
                        case .second(let tap):
                            guard let coordinate = proxy.convert(tap.location, from: .local) else { return }
                            let label = labelReader.selection(at: tap.location)
                            pickedCoordinate = PendingCoordinate(
                                coordinate: label?.coordinate ?? coordinate,
                                name: label?.name
                            )
                        }
                    }
            )
            // Retain Option-click as a shortcut straight into the editor.
            .simultaneousGesture(
                SpatialTapGesture()
                    .modifiers(.option)
                    .onEnded { value in
                        guard let coordinate = proxy.convert(value.location, from: .local) else { return }
                        pickedCoordinate = nil
                        let label = labelReader.selection(at: value.location)
                        pendingCoordinate = PendingCoordinate(
                            coordinate: label?.coordinate ?? coordinate,
                            name: label?.name
                        )
                    }
            )
            .overlay(alignment: .topLeading) { statsCard }
            .overlay(alignment: .bottomLeading) {
                if let pickedCoordinate {
                    MapCheckInCard(
                        coordinate: pickedCoordinate.coordinate,
                        name: pickedCoordinate.name,
                        onCheckIn: { pendingCoordinate = pickedCoordinate },
                        onCancel: { self.pickedCoordinate = nil }
                    )
                    .padding(12)
                    .padding(.bottom, 20) // Keep the map attribution visible.
                } else {
                    hintBar
                }
            }
            .overlay(alignment: .bottomTrailing) { legend }
        }
        .sheet(item: $pendingCoordinate) { pending in
            AddPlaceSheet(coordinate: pending.coordinate, name: pending.name) { newPlace in
                pickedCoordinate = nil
                onPlaceCreated(newPlace)
            }
        }
        .onChange(of: selectedCity) { _, _ in pickedCoordinate = nil }
        .onChange(of: selectedTrip?.id) { _, _ in pickedCoordinate = nil }
        .onChange(of: selectedPlaceID) { _, _ in pickedCoordinate = nil }
        .onChange(of: cameraResetRequest?.id) { _, _ in
            guard let request = cameraResetRequest else { return }
            pickedCoordinate = nil
            let applied = mapAccessor.resetCamera(request)
            Logger(subsystem: "com.weicheng.waymark", category: "Camera")
                .info("Overview reset delivered to native map: \(applied)")
        }
    }

    @MapContentBuilder
    private func placeAnnotation(_ place: Place) -> some MapContent {
        Annotation(place.name, coordinate: place.coordinate) {
            PlacePinView(place: place, isSelected: place.id == selectedPlaceID)
                .onTapGesture {
                    pickedCoordinate = nil
                    selectedPlaceID = place.id
                }
        }
        .annotationTitles(.hidden)
    }

    // MARK: - Overlays

    private var statsCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedTrip?.routeText ?? selectedCity ?? "全部打卡点")
                    .font(.system(size: WaymarkType.callout, weight: .bold))
                Text(selectedTrip.map { "\($0.dateRangeText) · \($0.placeCount) 个地点 · \($0.photoCount) 张照片" }
                     ?? "\(visiblePlaces.count) 个地点 · \(visiblePlaces.reduce(0) { $0 + $1.photos.count }) 张照片")
                    .font(.system(size: WaymarkType.footnote))
                    .foregroundStyle(.secondary)
            }

            if let coverageSummary {
                Divider().frame(height: 30)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(coverageSummary.coveragePercent)%")
                        .font(.system(size: WaymarkType.title2, weight: .bold))
                        .foregroundStyle(CoveragePalette.visited)
                    Text("探索度")
                        .font(.system(size: WaymarkType.caption))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, WaymarkMetric.cardPadding)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: WaymarkMetric.cardRadiusLarge))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .padding(12)
    }

    private var hintBar: some View {
        Text(store.places.isEmpty
             ? "点击地图选位置，再点「在这里打卡」"
             : selectedTrip != nil
               ? "数字是这趟行程的先后顺序，点编号可跳到那一段"
               : "点击地图选位置打卡 · ⌥ 点击可直接新建")
            .font(.system(size: WaymarkType.caption))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: Capsule())
            .padding(12)
    }

    @ViewBuilder
    private var legend: some View {
        if pickedCoordinate == nil, showsCoverageGrid, coverageSummary != nil {
            legendRow(color: CoveragePalette.visited, label: "已到过（打卡点 1.5 公里内）")
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: WaymarkMetric.cardRadiusSmall))
            .padding(12)
            .padding(.bottom, 28) // clears the Apple Maps attribution
        }
    }

    private func legendRow(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 12)
            Text(label)
                .font(.system(size: WaymarkType.caption))
                .foregroundStyle(.secondary)
        }
    }

    /// Only records the choice — `ContentView` owns the camera and reframes it,
    /// because it also knows when the map isn't on screen (photo gallery) and a
    /// freshly re-created `MapCanvasView` would never see the change itself.
    private func focus(city: String) {
        selectedCity = city
    }
}

struct PendingCoordinate: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    var name: String? = nil
}

enum MapStyleChoice: String, CaseIterable, Identifiable {
    case standard, hybrid

    var id: String { rawValue }
    var displayName: String { self == .standard ? "标准" : "卫星" }

    var mapStyle: MapStyle {
        switch self {
        case .standard: .standard(elevation: .flat)
        case .hybrid: .hybrid(elevation: .flat)
        }
    }
}
