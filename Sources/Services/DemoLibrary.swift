import Foundation

/// Entirely fictional travel history at public landmark coordinates.
/// Never reads or copies a personal library. Normal launch starts with user's own library.
enum DemoLibrary {
    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("--demo") }

    static func prepare(at folder: URL, assets: URL?) throws {
        let fm = FileManager.default
        let dataFile = folder.appendingPathComponent("data.json")
        guard !fm.fileExists(atPath: dataFile.path) else { return }
        guard let assets else { throw CocoaError(.fileNoSuchFile) }
        let photosFolder = folder.appendingPathComponent("Photos")
        try fm.createDirectory(at: photosFolder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var places = makePlaces()
        let images = ["coast.png", "garden.png", "lake.png"]
        for p in places.indices {
            let date = places[p].visits[0].date
            for index in 0..<3 {
                let name = "demo-\(p)-\(index).png"
                let destination = photosFolder.appendingPathComponent(name)
                if !fm.fileExists(atPath: destination.path) {
                    try fm.copyItem(at: assets.appendingPathComponent(images[index]), to: destination)
                }
                places[p].photos.append(Photo(fileName: name, thumbnailFileName: "",
                    capturedDate: date.addingTimeInterval(Double(index) * 600),
                    caption: "AI 生成的旅行氛围示意图，非此景点实拍 / AI-generated illustration, not a photograph of this landmark."))
            }
        }
        let kinds: [String: CityKind] = ["Porto": .resident, "Coimbra": .travel, "Lisbon": .travel, "Sintra": .travel]
        try encoder.encode(kinds).write(to: folder.appendingPathComponent("cities.json"), options: .atomic)
        try encoder.encode(places).write(to: dataFile, options: .atomic)
    }

    static func makePlaces() -> [Place] {
        let stops: [(String, String, Double, Double, String)] = [
            ("Ribeira · 河岸漫步", "Porto", 41.1406, -8.6131, "2025-04-10T09:00:00Z"),
            ("Jardins do Palácio de Cristal", "Porto", 41.1480, -8.6258, "2025-04-10T15:00:00Z"),
            ("University of Coimbra", "Coimbra", 40.2076, -8.4264, "2025-04-12T10:00:00Z"),
            ("Jardim Botânico · 植物园", "Coimbra", 40.2057, -8.4216, "2025-04-12T15:00:00Z"),
            ("Belém Tower · 贝伦塔", "Lisbon", 38.6916, -9.2160, "2025-04-14T10:00:00Z"),
            ("Praça do Comércio · 商业广场", "Lisbon", 38.7077, -9.1365, "2025-04-14T16:00:00Z"),
            ("Palácio da Pena · 佩纳宫", "Sintra", 38.7876, -9.3906, "2025-04-16T09:00:00Z"),
            ("Quinta da Regaleira", "Sintra", 38.7960, -9.3960, "2025-04-16T14:00:00Z"),
            ("Foz do Douro · 海边散步", "Porto", 41.1485, -8.6746, "2025-06-07T10:00:00Z"),
            ("Parque da Cidade · 城市公园", "Porto", 41.1660, -8.6760, "2025-06-08T10:00:00Z")
        ]
        let formatter = ISO8601DateFormatter()
        return stops.enumerated().map { index, stop in
            var place = Place(name: stop.0, city: stop.1, country: "Portugal · 演示", latitude: stop.2, longitude: stop.3, category: .landmark)
            place.id = UUID(uuidString: String(format: "D0000000-0000-4000-8000-%012d", index + 1))!
            let date = formatter.date(from: stop.4)!
            place.createdAt = date
            var visit = Visit(date: date, note: "【虚构演示 / Fictional demo】\n放慢脚步，把风景和心情一起收藏。下一次回到这里，还可以写下不同的感受。\nA quiet stop, a little wonder, a memory pinned to the map.")
            visit.id = UUID(uuidString: String(format: "D1000000-0000-4000-8000-%012d", index + 1))!
            place.visits = [visit]
            return place
        }
    }
}
