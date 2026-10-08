import Foundation
import Observation

/// The whole persistence layer: one JSON file of `Place` values, rewritten on
/// every mutation. The iPhone app uses SwiftData; this app is standalone (no
/// sync yet) and its data set is a few hundred places at most, so a plain file
/// avoids a store migration story for something that fits in memory anyway.
@Observable
final class DataStore {
    private(set) var places: [Place] = []

    /// City name → how that city figures in your life. Kept in its own file
    /// rather than folded into `data.json`, so classifying cities doesn't
    /// change the shape of the places file that already exists on disk.
    private(set) var cityKinds: [String: CityKind] = [:]

    /// Coverage grids are hundreds of cells and get asked for from computed
    /// properties on every view update — the sidebar alone recomputes one per
    /// city. Cached until the next mutation. `@ObservationIgnored` because
    /// filling the cache from inside a getter must not register as a change to
    /// observed state mid-update.
    @ObservationIgnored private var coverageCache: [String: CityCoverageSummary] = [:]
    @ObservationIgnored private var tripsCache: [Trip]?

    static var appFolder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        if DemoLibrary.isEnabled {
            let demo = base.appendingPathComponent("Waymark-Demo", isDirectory: true)
            try? FileManager.default.createDirectory(at: demo, withIntermediateDirectories: true)
            return demo
        }
        let folder = base.appendingPathComponent("Waymark", isDirectory: true)

        // The app was called WaypointMac before; move that folder over wholesale
        // rather than starting empty. Only ever runs once — after the move the
        // old path no longer exists.
        let legacy = base.appendingPathComponent("WaypointMac", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path),
           FileManager.default.fileExists(atPath: legacy.path) {
            try? FileManager.default.moveItem(at: legacy, to: folder)
        }

        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private let storageFolder: URL
    private var fileURL: URL { storageFolder.appendingPathComponent("data.json") }
    private var cityKindsURL: URL { storageFolder.appendingPathComponent("cities.json") }

    init(storageFolder: URL = DataStore.appFolder) {
        self.storageFolder = storageFolder
        load()
    }

    // MARK: - Persistence

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = try? Data(contentsOf: fileURL) {
            places = (try? decoder.decode([Place].self, from: data)) ?? []
        } else {
            places = []
        }

        if let data = try? Data(contentsOf: cityKindsURL) {
            cityKinds = (try? decoder.decode([String: CityKind].self, from: data)) ?? [:]
        }

        let cleared = PhotoStorage.removeLegacyThumbnails(
            for: places.flatMap(\.photos), directory: storageFolder.appendingPathComponent("Photos")
        )
        if !cleared.isEmpty {
            for placeIndex in places.indices {
                for photoIndex in places[placeIndex].photos.indices {
                    if cleared.contains(places[placeIndex].photos[photoIndex].thumbnailFileName) {
                        places[placeIndex].photos[photoIndex].thumbnailFileName = ""
                    }
                }
            }
            save()
        }
    }

    private func save() {
        coverageCache.removeAll()
        tripsCache = nil
        guard let data = try? encoder.encode(places) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func saveCityKinds() {
        guard let data = try? encoder.encode(cityKinds) else { return }
        try? data.write(to: cityKindsURL, options: .atomic)
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    // MARK: - Derived views

    func place(id: UUID) -> Place? {
        places.first { $0.id == id }
    }

    func places(inCity city: String) -> [Place] {
        places.filter { $0.city == city }
    }

    var cityAggregates: [CityAggregate] {
        CityAggregate.aggregate(places: places) { [weak self] city in
            self?.coverageSummary(forCity: city)?.coveragePercent ?? 0
        }
    }

    var cityNames: [String] {
        cityAggregates.map(\.city)
    }

    func kind(forCity city: String) -> CityKind {
        cityKinds[city] ?? .default
    }

    func setKind(_ kind: CityKind, forCity city: String) {
        cityKinds[canonicalCityName(city)] = kind
        saveCityKinds()
    }

    func canonicalCityName(_ city: String) -> String {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = Set(places.map(\.city)).union(cityKinds.keys)
        if existing.contains(trimmed) { return trimmed }
        if trimmed.hasSuffix("市"), existing.contains(String(trimmed.dropLast())) {
            return String(trimmed.dropLast())
        }
        if existing.contains(trimmed + "市") { return trimmed + "市" }
        return trimmed
    }

    func needsCityClassification(_ city: String) -> Bool {
        let name = canonicalCityName(city)
        return !name.isEmpty && cityKinds[name] == nil
    }

    /// Aggregates split into the two city kinds, each still ordered by place
    /// count. Cities with no explicit classification fall into `.travel`.
    func cityAggregates(ofKind kind: CityKind) -> [CityAggregate] {
        cityAggregates.filter { self.kind(forCity: $0.city) == kind }
    }

    var photoCount: Int {
        places.reduce(0) { $0 + $1.photos.count }
    }

    /// Journeys derived from visit dates. Cached alongside coverage — the
    /// sidebar asks for this on every view update.
    var trips: [Trip] {
        if let tripsCache { return tripsCache }
        let built = TripBuilder.build(from: places)
        tripsCache = built
        return built
    }

    func trip(id: String) -> Trip? {
        trips.first { $0.id == id }
    }

    func coverageSummary(forCity city: String) -> CityCoverageSummary? {
        if let cached = coverageCache[city] { return cached }
        guard let summary = CityCoverageCalculator.summarize(places: places(inCity: city)) else {
            return nil
        }
        coverageCache[city] = summary
        return summary
    }

    // MARK: - Mutations

    @discardableResult
    func add(_ place: Place, cityKind: CityKind? = nil) -> Place {
        var place = place
        place.city = canonicalCityName(place.city)
        if let cityKind, !place.city.isEmpty { setKind(cityKind, forCity: place.city) }
        places.append(place)
        save()
        return place
    }

    func update(_ place: Place) {
        guard let index = places.firstIndex(where: { $0.id == place.id }) else { return }
        places[index] = place
        save()
    }

    /// Deletes the place and the image files belonging to its photos. The
    /// iPhone app keeps orphaned photos in a global library; here a photo only
    /// ever exists attached to a place, so nothing would be able to reach them.
    func deletePlace(id: UUID) {
        guard let index = places.firstIndex(where: { $0.id == id }) else { return }
        for photo in places[index].photos {
            PhotoStorage.delete(fileName: photo.fileName, directory: storageFolder.appendingPathComponent("Photos"))
            PhotoStorage.delete(fileName: photo.thumbnailFileName, directory: storageFolder.appendingPathComponent("Photos"))
        }
        places.remove(at: index)
        save()
    }

    /// Deletes a city and everything filed under it. Irreversible — callers
    /// confirm first.
    func deleteCity(_ city: String) {
        for place in places where place.city == city {
            for photo in place.photos {
                PhotoStorage.delete(fileName: photo.fileName, directory: storageFolder.appendingPathComponent("Photos"))
                PhotoStorage.delete(fileName: photo.thumbnailFileName, directory: storageFolder.appendingPathComponent("Photos"))
            }
        }
        places.removeAll { $0.city == city }
        cityKinds.removeValue(forKey: city)
        save()
        saveCityKinds()
    }

    /// Retitles every place filed under `old`. Renaming onto a name that
    /// already exists merges the two — which is the fix for the same city
    /// existing twice under different spellings, since grouping is by raw
    /// string. The surviving city keeps the destination's classification.
    @discardableResult
    func renameCity(_ old: String, to new: String) -> Bool {
        let trimmed = new.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != old else { return false }

        for index in places.indices where places[index].city == old {
            places[index].city = trimmed
        }
        if let kind = cityKinds.removeValue(forKey: old), cityKinds[trimmed] == nil {
            cityKinds[trimmed] = kind
        }
        save()
        saveCityKinds()
        return true
    }

    func addVisit(_ visit: Visit, toPlace placeID: UUID) {
        mutate(placeID) { $0.visits.append(visit) }
    }

    /// Replaces a visit in place, matched by id — so editing a mistyped date
    /// keeps the record rather than making you delete and re-add it.
    func updateVisit(_ visit: Visit, inPlace placeID: UUID) {
        mutate(placeID) { place in
            guard let index = place.visits.firstIndex(where: { $0.id == visit.id }) else { return }
            place.visits[index] = visit
        }
    }

    func deleteVisit(id visitID: UUID, fromPlace placeID: UUID) {
        mutate(placeID) { $0.visits.removeAll { $0.id == visitID } }
    }

    /// Update only the selected visit's feelings, using the latest stored value.
    /// A stale editor cannot overwrite another visit, date, photos, or category.
    func updateVisitFeeling(_ feeling: String, visitID: UUID, placeID: UUID) throws {
        guard let p = places.firstIndex(where: { $0.id == placeID }),
              let v = places[p].visits.firstIndex(where: { $0.id == visitID }) else { return }
        var updated = places
        updated[p].visits[v].note = feeling
        try commitPlaces(updated)
    }

    /// Legacy place-wide notes have no visit identity. Assign only on user request,
    /// append without overwriting existing feelings, and clear only after saving.
    func assignLegacyFeeling(toVisit visitID: UUID, placeID: UUID) throws {
        guard let p = places.firstIndex(where: { $0.id == placeID }),
              let v = places[p].visits.firstIndex(where: { $0.id == visitID }),
              !places[p].notes.isEmpty else { return }
        var updated = places
        let legacy = updated[p].notes
        if updated[p].visits[v].note.isEmpty {
            updated[p].visits[v].note = legacy
        } else {
            updated[p].visits[v].note += "\n\n" + legacy
        }
        updated[p].notes = ""
        try commitPlaces(updated)
    }

    func addPhotos(_ photos: [Photo], toPlace placeID: UUID) {
        mutate(placeID) { $0.photos.append(contentsOf: photos) }
    }

    func deletePhoto(id photoID: UUID, fromPlace placeID: UUID) {
        guard let index = places.firstIndex(where: { $0.id == placeID }),
              let photo = places[index].photos.first(where: { $0.id == photoID }) else { return }
        PhotoStorage.delete(fileName: photo.fileName, directory: storageFolder.appendingPathComponent("Photos"))
        PhotoStorage.delete(fileName: photo.thumbnailFileName, directory: storageFolder.appendingPathComponent("Photos"))
        places[index].photos.removeAll { $0.id == photoID }
        save()
    }

    func updatePhotoCaption(_ caption: String, photoID: UUID, placeID: UUID) {
        mutate(placeID) { place in
            guard let index = place.photos.firstIndex(where: { $0.id == photoID }) else { return }
            place.photos[index].caption = caption
        }
    }

    /// Batch edits commit once. Nil fields are intentionally left unchanged.
    func updatePhotos(ids: Set<UUID>, inPlace placeID: UUID, capturedDate: Date?, caption: String?) throws {
        guard !ids.isEmpty, capturedDate != nil || caption != nil,
              let index = places.firstIndex(where: { $0.id == placeID }) else { return }
        var updated = places
        for photoIndex in updated[index].photos.indices where ids.contains(updated[index].photos[photoIndex].id) {
            if let capturedDate { updated[index].photos[photoIndex].capturedDate = capturedDate }
            if let caption { updated[index].photos[photoIndex].caption = caption }
        }
        try commitPlaces(updated)
    }

    func deletePhotos(ids: Set<UUID>, fromPlace placeID: UUID) throws {
        guard !ids.isEmpty, let index = places.firstIndex(where: { $0.id == placeID }) else { return }
        let removed = places[index].photos.filter { ids.contains($0.id) }
        guard !removed.isEmpty else { return }
        var updated = places
        updated[index].photos.removeAll { ids.contains($0.id) }
        // Never remove bytes before the metadata has safely reached disk.
        try commitPlaces(updated)
        let retainedNames = Set(updated.flatMap(\.photos).flatMap { [$0.fileName, $0.thumbnailFileName] })
        let directory = storageFolder.appendingPathComponent("Photos")
        for name in Set(removed.flatMap { [$0.fileName, $0.thumbnailFileName] }) {
            guard !name.isEmpty, !retainedNames.contains(name),
                  name != ".", name != "..",
                  URL(fileURLWithPath: name).lastPathComponent == name else { continue }
            let url = directory.appendingPathComponent(name)
            guard let attributes = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
                  attributes.isRegularFile == true || attributes.isSymbolicLink == true else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func commitPlaces(_ updated: [Place]) throws {
        let data = try encoder.encode(updated)
        try data.write(to: fileURL, options: .atomic)
        places = updated
        coverageCache.removeAll()
        tripsCache = nil
    }

    func rotatePhoto(quarterTurns: Int, photoID: UUID, placeID: UUID) {
        mutate(placeID) { place in
            guard let index = place.photos.firstIndex(where: { $0.id == photoID }) else { return }
            place.photos[index].rotationQuarterTurns = ((quarterTurns % 4) + 4) % 4
        }
    }

    private func mutate(_ placeID: UUID, _ body: (inout Place) -> Void) {
        guard let index = places.firstIndex(where: { $0.id == placeID }) else { return }
        body(&places[index])
        save()
    }
}
