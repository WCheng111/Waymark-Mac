import SwiftUI

/// A window carries IDs, not a second copy of the photo library. Each request
/// gets its own window-scoped navigation and zoom state.
struct PhotoViewerRequest: Codable, Hashable {
    static let windowID = "photo-viewer"
    var id = UUID()
    let placeID: UUID
    let photoIDs: [UUID]
    let selectedPhotoID: UUID

    init?(placeID: UUID, photos: [Photo], index: Int) {
        guard photos.indices.contains(index) else { return nil }
        self.placeID = placeID
        photoIDs = photos.map(\.id)
        selectedPhotoID = photos[index].id
    }

    func photos(in store: DataStore) -> [Photo] {
        let current = Dictionary(uniqueKeysWithValues: (store.place(id: placeID)?.photos ?? []).map { ($0.id, $0) })
        return photoIDs.compactMap { current[$0] }
    }
}

struct PhotoViewerWindow: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let request: PhotoViewerRequest?

    var body: some View {
        Group {
            if let request, !request.photos(in: store).isEmpty {
                let photos = request.photos(in: store)
                PhotoViewer(placeID: request.placeID, photos: photos,
                            index: photos.firstIndex { $0.id == request.selectedPhotoID } ?? 0) {
                    dismiss()
                }
                .id(request.id)
                .navigationTitle("\(store.place(id: request.placeID)?.name ?? "照片") · 照片查看器")
            } else {
                ContentUnavailableView("没有可查看的照片", systemImage: "photo",
                                       description: Text("请从地点的照片列表中打开图片。"))
            }
        }
        .frame(minWidth: 640, minHeight: 400)
    }
}
