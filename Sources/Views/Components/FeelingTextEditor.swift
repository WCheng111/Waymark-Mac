import SwiftUI
import AppKit

/// A small text-system bridge: Return finishes; Shift+Return inserts a newline.
/// Marked text is always handled by AppKit so IME confirmation cannot finish editing.
struct FeelingTextEditor: NSViewRepresentable {
    let text: String
    let onChange: (String) -> Void
    let onFinish: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        let editor = FeelingNSTextView(frame: .zero)
        editor.isRichText = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.allowsUndo = true
        editor.font = .systemFont(ofSize: WaymarkType.body)
        editor.textColor = .textColor
        editor.drawsBackground = false
        editor.textContainerInset = NSSize(width: 3, height: 5)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        editor.string = text
        editor.setAccessibilityLabel("到访感受（编辑模式）")
        editor.delegate = context.coordinator
        editor.onFinish = onFinish
        scroll.documentView = editor
        DispatchQueue.main.async { [weak editor] in
            guard let editor, let window = editor.window else { return }
            window.makeFirstResponder(editor)
            editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? FeelingNSTextView else { return }
        editor.onFinish = onFinish
        // Never replace live typing/marked text. Changes are already saved by the
        // delegate; each visit creates a fresh representable via its stable ID.
        if scroll.window?.firstResponder !== editor, !editor.hasMarkedText(), editor.string != text {
            editor.string = text
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: FeelingTextEditor
        init(parent: FeelingTextEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView, !editor.hasMarkedText() else { return }
            parent.onChange(editor.string)
        }
    }
}

final class FeelingNSTextView: NSTextView {
    var onFinish: ((String) -> Void)?

    static func shouldFinish(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, hasMarkedText: Bool) -> Bool {
        (keyCode == 36 || keyCode == 76) && !modifiers.contains(.shift) && !hasMarkedText
    }

    override func keyDown(with event: NSEvent) {
        if Self.shouldFinish(keyCode: event.keyCode, modifiers: event.modifierFlags, hasMarkedText: hasMarkedText()) {
            onFinish?(string)
        } else if (event.keyCode == 36 || event.keyCode == 76), event.modifierFlags.contains(.shift), !hasMarkedText() {
            insertNewline(nil)
        } else {
            super.keyDown(with: event)
        }
    }
}
