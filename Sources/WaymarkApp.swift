import SwiftUI
import AppKit

@main
struct WaymarkApp: App {
    @State private var store: DataStore
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        if DemoLibrary.isEnabled {
            do { try DemoLibrary.prepare(at: DataStore.appFolder, assets: Bundle.main.resourceURL?.appendingPathComponent("Demo")) }
            catch { NSLog("Unable to prepare demo library: %@", error.localizedDescription) }
        }
        _store = State(initialValue: DataStore())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .frame(minWidth: 900, minHeight: 560)
                .safeAreaInset(edge: .bottom) {
                    if DemoLibrary.isEnabled {
                        Text("演示模式 · 虚构旅行与 AI 示意图 · Demo library — no personal data")
                            .font(.caption).padding(6).frame(maxWidth: .infinity)
                            .background(.orange.opacity(0.12))
                    }
                }
        }
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button("打开演示资料库 / Open Demo Library") {
                    let configuration = NSWorkspace.OpenConfiguration()
                    configuration.createsNewApplicationInstance = true
                    configuration.arguments = ["--demo"]
                    NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration)
                }
                Button("在访达中显示数据文件夹") {
                    NSWorkspace.shared.activateFileViewerSelecting([DataStore.appFolder])
                }
            }
        }

        WindowGroup("照片查看器", id: PhotoViewerRequest.windowID, for: PhotoViewerRequest.self) { $request in
            PhotoViewerWindow(request: request)
                .environment(store)
        }
        .defaultSize(width: 860, height: 640)
        .windowResizability(.contentMinSize)
    }
}

/// A SwiftPM-built binary isn't launched the way a bundled app is, so without
/// this it starts as a background process with no menu bar and no focused
/// window. Promoting it to `.regular` and activating gives normal app behavior.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
