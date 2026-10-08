import SwiftUI
import MapKit
import CoreLocation

/// New-place editor: drag the map under the crosshair to set the exact spot,
/// or search for it by name. Mirrors the iPhone app's `AddPlaceView`, with the
/// map given more room since a Mac window has it to spare.
struct AddPlaceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataStore.self) private var store

    @State private var cameraPosition: MapCameraPosition
    @State private var selectedCoordinate: CLLocationCoordinate2D
    @State private var name = ""
    @State private var city = ""
    @State private var country = ""
    @State private var category: PlaceCategory = .other
    @State private var visitDate = Date()
    @State private var note = ""
    @State private var isLookingUp = false
    @State private var isShowingSearch = false
    @State private var isChoosingCityKind = false
    @State private var cityWasEdited = false
    @State private var lookupFailed = false
    @State private var lookupRequestID = UUID()

    private let onCreated: (Place) -> Void

    init(coordinate: CLLocationCoordinate2D, name: String? = nil, onCreated: @escaping (Place) -> Void) {
        _cameraPosition = State(initialValue: .region(
            MKCoordinateRegion(center: coordinate, latitudinalMeters: 900, longitudinalMeters: 900)
        ))
        _selectedCoordinate = State(initialValue: coordinate)
        // A name explicitly selected on the map takes precedence over the
        // reverse geocoder's street/town name. Lookup only fills empty fields.
        _name = State(initialValue: name ?? "")
        self.onCreated = onCreated
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            HStack(spacing: 0) {
                mapPicker
                    .frame(width: 380)
                Divider()
                form
                    .frame(width: 320)
            }

            Divider()
            footer
        }
        .frame(height: 480)
        .task(id: coordinateKey) { await lookUpPlacemark() }
        .sheet(isPresented: $isShowingSearch) {
            PlaceSearchSheet(
                regionHint: MKCoordinateRegion(center: selectedCoordinate, latitudinalMeters: 50_000, longitudinalMeters: 50_000),
                onSelect: selectSearchResult
            )
        }
        .alert("为「\(resolvedCity)」选择城市分类", isPresented: $isChoosingCityKind) {
            Button(CityKind.resident.sectionTitle) { save(cityKind: .resident) }
            Button(CityKind.travel.sectionTitle) { save(cityKind: .travel) }
            Button("取消", role: .cancel) {}
        } message: {
            Text("保存打卡后，这座城市会自动出现在左侧栏目，无需另外新建城市。")
        }
    }

    private var header: some View {
        HStack {
            Text("新建打卡地点")
                .font(.system(size: WaymarkType.callout, weight: .semibold))
            Spacer()
            Button {
                isShowingSearch = true
            } label: {
                Label("搜索地点", systemImage: "magnifyingglass")
            }
        }
        .padding(12)
    }

    private var mapPicker: some View {
        ZStack {
            Map(position: $cameraPosition)
                .onMapCameraChange(frequency: .onEnd) { context in
                    let previous = CLLocation(latitude: selectedCoordinate.latitude, longitude: selectedCoordinate.longitude)
                    let next = CLLocation(latitude: context.region.center.latitude, longitude: context.region.center.longitude)
                    guard previous.distance(from: next) > 1 else { return }
                    selectedCoordinate = context.region.center
                    cityWasEdited = false
                    city = ""
                    isLookingUp = true
                }

            // Fixed crosshair over a movable map: the pin never lags the drag,
            // and the coordinate is always exactly the map's center.
            Image(systemName: "mappin")
                .font(.system(size: 30))
                .foregroundStyle(.red)
                .shadow(radius: 1)
                .offset(y: -15)
                .allowsHitTesting(false)

            VStack {
                Spacer()
                Text("拖动地图调整打卡位置")
                    .font(.system(size: WaymarkType.caption))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 8)
            }
            .allowsHitTesting(false)
        }
    }

    private var form: some View {
        Form {
            Section("地点信息") {
                TextField("名称", text: $name)
                TextField("城市", text: Binding(
                    get: { city },
                    set: { city = $0; cityWasEdited = true }
                ))
                if !resolvedCity.isEmpty, store.needsCityClassification(resolvedCity) {
                    Text("新城市：保存时选择城市分类，自动加入左侧栏目。")
                        .font(.system(size: WaymarkType.footnote))
                        .foregroundStyle(.secondary)
                }
                TextField("国家/地区", text: $country)
                Picker("分类", selection: $category) {
                    ForEach(PlaceCategory.allCases) { category in
                        Label(category.displayName, systemImage: category.symbolName).tag(category)
                    }
                }
                if isLookingUp {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("正在识别地点…")
                            .font(.system(size: WaymarkType.footnote))
                            .foregroundStyle(.secondary)
                    }
                } else if lookupFailed || resolvedCity.isEmpty {
                    Text("未能识别城市，请填写城市名称后保存。")
                        .font(.system(size: WaymarkType.footnote))
                        .foregroundStyle(.secondary)
                }
            }

            Section("到访记录") {
                DatePicker("到访日期", selection: $visitDate, in: WaymarkDateFormat.visitDateRange, displayedComponents: .date)
                TextField("到访感受（可选）", text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section {
                Text(String(format: "%.5f, %.5f", selectedCoordinate.latitude, selectedCoordinate.longitude))
                    .font(.system(size: WaymarkType.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("取消") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("保存") {
                if store.needsCityClassification(resolvedCity) {
                    isChoosingCityKind = true
                } else {
                    save()
                }
            }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || resolvedCity.isEmpty || isLookingUp)
        }
        .padding(12)
    }

    /// Selecting a search result is a deliberate, specific choice, so unlike
    /// the passive drag-to-reverse-geocode flow it overwrites what's already
    /// filled in, including a previously selected city's name.
    private func selectSearchResult(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        selectedCoordinate = coordinate
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(center: coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
            )
        }
        name = item.name ?? name
        cityWasEdited = false
        city = store.canonicalCityName(ReverseGeocodingService.cityName(for: item.placemark))
        country = item.placemark.country ?? ""
    }

    private func lookUpPlacemark() async {
        let requestID = UUID()
        lookupRequestID = requestID
        let coordinate = selectedCoordinate
        isLookingUp = true
        defer { if lookupRequestID == requestID { isLookingUp = false } }
        // Coalesce map movements; never let an old city's result overwrite a
        // newer coordinate or a city the user has explicitly entered.
        do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
        let result = await ReverseGeocodingService.shared.lookUp(coordinate: coordinate)
        guard !Task.isCancelled, lookupRequestID == requestID,
              selectedCoordinate.latitude == coordinate.latitude,
              selectedCoordinate.longitude == coordinate.longitude else { return }
        lookupFailed = result == nil
        guard let result else { return }
        if name.isEmpty { name = result.name }
        if !cityWasEdited { city = store.canonicalCityName(result.city) }
        if country.isEmpty { country = result.country }
    }

    private var coordinateKey: String {
        "\(selectedCoordinate.latitude),\(selectedCoordinate.longitude)"
    }

    private var resolvedCity: String { store.canonicalCityName(city) }

    private func save(cityKind: CityKind? = nil) {
        guard !resolvedCity.isEmpty, !isLookingUp else { return }
        var place = Place(
            name: name.trimmingCharacters(in: .whitespaces),
            city: resolvedCity,
            country: country.trimmingCharacters(in: .whitespaces),
            latitude: selectedCoordinate.latitude,
            longitude: selectedCoordinate.longitude,
            category: category
        )
        place.visits = [Visit(date: visitDate, note: note)]
        store.add(place, cityKind: cityKind)
        onCreated(place)
        dismiss()
    }
}
