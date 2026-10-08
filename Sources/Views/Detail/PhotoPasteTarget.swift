import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Focus only the photo area on an explicit click. Text fields remain native
/// first responders and therefore retain their own paste behavior.
@MainActor
final class PhotoPasteTarget {
    weak var view: NSView?

    func focus() {
        guard let view else { return }
        view.window?.makeFirstResponder(view)
    }
}

struct PhotoPasteCommandHandler: NSViewRepresentable {
    let target: PhotoPasteTarget
    var onPaste: () -> Void

    func makeNSView(context: Context) -> PasteView {
        let view = PasteView()
        view.onPaste = onPaste
        target.view = view
        return view
    }

    func updateNSView(_ nsView: PasteView, context: Context) {
        nsView.onPaste = onPaste
        target.view = nsView
    }

    static func dismantleNSView(_ nsView: PasteView, coordinator: ()) {
        if nsView.window?.firstResponder === nsView {
            nsView.window?.makeFirstResponder(nil)
        }
        nsView.onPaste = {}
    }

    final class PasteView: NSView, NSUserInterfaceValidations {
        var onPaste: () -> Void = {}
        override var acceptsFirstResponder: Bool { true }
        // The background anchor must not swallow thumbnail/button clicks.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        @objc func paste(_ sender: Any?) { onPaste() }

        func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
            item.action == #selector(paste(_:)) && NSPasteboard.general.canReadItem(
                withDataConformingToTypes: [UTType.image.identifier, UTType.fileURL.identifier]
            )
        }
    }
}
