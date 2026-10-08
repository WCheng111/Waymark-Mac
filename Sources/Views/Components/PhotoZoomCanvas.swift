import SwiftUI

enum PhotoViewportGeometry {
    static func fittedSize(image: CGSize, viewport: CGSize, quarterTurns: Int) -> CGSize {
        guard image.width > 0, image.height > 0 else { return .zero }
        let swapped = quarterTurns % 2 != 0
        let width = swapped ? image.height : image.width
        let height = swapped ? image.width : image.height
        let scale = min(max(0, viewport.width - 16) / width, max(0, viewport.height - 16) / height)
        return CGSize(width: image.width * scale, height: image.height * scale)
    }

    static func clampedOffset(_ offset: CGSize, image: CGSize, viewport: CGSize, quarterTurns: Int, zoom: CGFloat) -> CGSize {
        let swapped = quarterTurns % 2 != 0
        let limitX = max(0, ((swapped ? image.height : image.width) * zoom - viewport.width) / 2)
        let limitY = max(0, ((swapped ? image.width : image.height) * zoom - viewport.height) / 2)
        return CGSize(width: min(limitX, max(-limitX, offset.width)), height: min(limitY, max(-limitY, offset.height)))
    }
}

/// Bounded panning keeps a magnified photo reachable; rotation is fitted using
/// the swapped dimensions, so portrait photos never get clipped at fit size.
struct PhotoZoomCanvas: View {
    let image: NSImage
    let quarterTurns: Int
    @Binding var zoom: CGFloat
    @State private var pan: CGSize = .zero
    @GestureState private var drag: CGSize = .zero
    @GestureState private var magnification: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            let fitted = PhotoViewportGeometry.fittedSize(image: image.size, viewport: geometry.size, quarterTurns: quarterTurns)
            let scale = min(8, max(0.25, zoom * magnification))
            let offset = bounded(CGSize(width: pan.width + drag.width, height: pan.height + drag.height), fitted: fitted, viewport: geometry.size, scale: scale)
            Image(nsImage: image)
                .resizable()
                .frame(width: fitted.width * scale, height: fitted.height * scale)
                .rotationEffect(.degrees(Double(quarterTurns) * 90))
                .offset(offset)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .contentShape(Rectangle())
                .clipped()
                .gesture(DragGesture()
                    .updating($drag) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        pan = bounded(CGSize(width: pan.width + value.translation.width, height: pan.height + value.translation.height), fitted: fitted, viewport: geometry.size, scale: scale)
                    })
                .simultaneousGesture(MagnificationGesture()
                    .updating($magnification) { value, state, _ in state = value }
                    .onEnded { zoom = min(8, max(0.25, zoom * $0)) })
                .onChange(of: zoom) { _, _ in pan = bounded(pan, fitted: fitted, viewport: geometry.size, scale: zoom) }
                .onChange(of: quarterTurns) { _, _ in pan = .zero }
                .onChange(of: geometry.size) { _, _ in
                    pan = bounded(pan, fitted: fitted, viewport: geometry.size, scale: zoom)
                }
        }
    }

    private func bounded(_ offset: CGSize, fitted: CGSize, viewport: CGSize, scale: CGFloat) -> CGSize {
        PhotoViewportGeometry.clampedOffset(offset, image: fitted, viewport: viewport, quarterTurns: quarterTurns, zoom: scale)
    }
}
