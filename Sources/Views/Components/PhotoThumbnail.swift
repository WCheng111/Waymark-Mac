import SwiftUI
import AppKit

/// Square thumbnail that **fills its grid cell**. A fixed-size frame inside an
/// adaptive `LazyVGrid` is what produced the uneven gaps: the columns stretch
/// to fill the width while the image stays 96pt and centers in the leftover
/// space. Sizing from a `Color.clear` aspect-ratio spacer instead means the
/// image is always exactly as wide as its column, so the only gap left is the
/// grid's own spacing.
struct PhotoThumbnail: View {
    let photo: Photo
    /// Fixed side length; `nil` fills the enclosing grid cell.
    var size: CGFloat? = nil
    var cornerRadius: CGFloat = WaymarkMetric.cardRadiusSmall

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .frame(width: size, height: size)
            .overlay { image }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(alignment: .topTrailing) {
                if !photo.caption.isEmpty {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(.black.opacity(0.35), in: Circle())
                        .padding(3)
                }
            }
    }

    @ViewBuilder
    private var image: some View {
        if let nsImage = PhotoStorage.preview(for: photo) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
                .rotationEffect(.degrees(Double(photo.displayQuarterTurns) * 90))
        } else {
            Rectangle()
                .fill(.secondary.opacity(0.15))
                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
        }
    }
}

/// Full-size viewer. Arrow keys and the on-hover chevrons step through the
/// place's photos in the same order the grid shows them.
struct PhotoViewer: View {
    @Environment(DataStore.self) private var store
    let placeID: UUID
    let photos: [Photo]
    @State var index: Int
    var onClose: () -> Void
    @State private var zoom: CGFloat = 1
    @State private var image: NSImage?

    private var photo: Photo? {
        guard photos.indices.contains(index) else { return nil }
        let selected = photos[index]
        return store.place(id: placeID)?.photos.first { $0.id == selected.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if let photo {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(WaymarkDateFormat.dayTime.string(from: photo.capturedDate))
                            .font(.system(size: WaymarkType.body, weight: .semibold))
                        if !photo.caption.isEmpty {
                            Text(photo.caption)
                                .font(.system(size: WaymarkType.footnote))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
                Text("\(index + 1) / \(photos.count)")
                    .font(.system(size: WaymarkType.footnote))
                    .foregroundStyle(.secondary)
                Button("完成", action: onClose)
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(12)

            Divider()

            HStack(spacing: 12) {
                Button { zoom = max(0.25, zoom / 1.25) } label: {
                    Label("缩小", systemImage: "minus.magnifyingglass")
                }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(zoom <= 0.25)
                Text("\(Int(zoom * 100))%")
                    .monospacedDigit().frame(width: 48)
                    .help("相对于适合窗口的大小")
                Button { zoom = min(8, zoom * 1.25) } label: {
                    Label("放大", systemImage: "plus.magnifyingglass")
                }
                .keyboardShortcut("=", modifiers: .command)
                .disabled(zoom >= 8)
                Button("适合窗口") { zoom = 1 }
                    .keyboardShortcut("0", modifiers: .command)
                Spacer()
                Button { rotate(-1) } label: { Label("左转", systemImage: "rotate.left") }
                Button { rotate(1) } label: { Label("右转", systemImage: "rotate.right") }
            }
            .disabled(image == nil)
            .padding(.horizontal, 12).padding(.vertical, 8)

            ZStack {
                Color.black.opacity(0.9)
                if let photo, let image {
                    PhotoZoomCanvas(image: image, quarterTurns: photo.displayQuarterTurns, zoom: $zoom)
                        .id(photo.id)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.5))
                }

                HStack {
                    stepButton("chevron.left", enabled: index > 0) { index -= 1 }
                    Spacer()
                    stepButton("chevron.right", enabled: index < photos.count - 1) { index += 1 }
                }
                .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .task(id: photo?.id) {
            zoom = 1
            image = photo.flatMap { NSImage(contentsOf: PhotoStorage.url(for: $0.fileName)) }
        }
        .onChange(of: photos.map(\.id)) { _, _ in
            index = min(index, max(0, photos.count - 1))
        }
    }

    private func rotate(_ turns: Int) {
        guard let photo else { return }
        zoom = 1
        store.rotatePhoto(quarterTurns: photo.displayQuarterTurns + turns, photoID: photo.id, placeID: placeID)
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.black.opacity(0.45), in: Circle())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0)
        .disabled(!enabled)
        .keyboardShortcut(symbol == "chevron.left" ? .leftArrow : .rightArrow, modifiers: [])
    }
}
