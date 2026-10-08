import AppKit
import XCTest
@testable import Waymark

final class FeelingEditorTests: XCTestCase {
    func testReturnAndKeypadEnterFinishButShiftAndIMEConfirmationDoNot() {
        for key: UInt16 in [36, 76] {
            XCTAssertTrue(FeelingNSTextView.shouldFinish(keyCode: key, modifiers: [], hasMarkedText: false))
            XCTAssertFalse(FeelingNSTextView.shouldFinish(keyCode: key, modifiers: .shift, hasMarkedText: false))
            XCTAssertFalse(FeelingNSTextView.shouldFinish(keyCode: key, modifiers: [], hasMarkedText: true))
            XCTAssertFalse(FeelingNSTextView.shouldFinish(keyCode: key, modifiers: .shift, hasMarkedText: true))
        }
        XCTAssertFalse(FeelingNSTextView.shouldFinish(keyCode: 0, modifiers: [], hasMarkedText: false))
        XCTAssertFalse(FeelingNSTextView.shouldFinish(keyCode: 51, modifiers: [], hasMarkedText: false))
    }

    func testEnterFinishesWithoutAddingNewlineAndShiftEnterKeepsEditing() throws {
        let editor = FeelingNSTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 140))
        editor.string = "到访感受"
        editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        var finished: [String] = []
        editor.onFinish = { finished.append($0) }
        func event(_ flags: NSEvent.ModifierFlags) throws -> NSEvent {
            try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                                         timestamp: 0, windowNumber: 0, context: nil, characters: "\r",
                                         charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        }
        editor.keyDown(with: try event([]))
        XCTAssertEqual(finished, ["到访感受"])
        XCTAssertEqual(editor.string, "到访感受")
        editor.keyDown(with: try event(.shift))
        XCTAssertEqual(finished.count, 1)
        XCTAssertEqual(editor.string, "到访感受\n")
    }
}
