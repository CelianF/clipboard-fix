import SwiftUI

// Universal Clipboard is controlled by `ClipboardSharingEnabled` in
// com.apple.coreservices.useractivityd. The ByHost (-currentHost) copy is the
// one System Settings manages; a stray copy in the plain user domain set to 0
// can be left behind by other software. The fix removes that stray key and
// restarts useractivityd (launchd relaunches it immediately).

private let domain = "com.apple.coreservices.useractivityd"
private let key = "ClipboardSharingEnabled"

enum ClipboardState: Equatable {
    case ok
    case strayKey(String)      // global-domain value that shouldn't be there
    case handoffOff            // the real (ByHost) setting is off
}

struct Clipboard {
    @discardableResult
    static func run(_ path: String, _ args: [String]) -> (status: Int32, output: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run() } catch { return (-1, error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let out = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return (p.terminationStatus, out)
    }

    static func state() -> ClipboardState {
        let host = run("/usr/bin/defaults", ["-currentHost", "read", domain, key])
        if host.status == 0 && host.output == "0" { return .handoffOff }
        let global = run("/usr/bin/defaults", ["read", domain, key])
        if global.status == 0 { return .strayKey(global.output) }
        return .ok
    }

    static func fix() -> String {
        if case .strayKey = state() {
            let r = run("/usr/bin/defaults", ["delete", domain, key])
            if r.status != 0 { return "Couldn't remove the key: \(r.output)" }
        }
        run("/usr/bin/killall", ["useractivityd"])
        run("/usr/bin/killall", ["pboard"])
        return "Done. Copy on your iPhone, then paste here."
    }
}

struct ContentView: View {
    @State private var state = Clipboard.state()
    @State private var message = ""
    @State private var working = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(tint)
            Text(title).font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                working = true
                Task.detached {
                    let result = Clipboard.fix()
                    try? await Task.sleep(for: .seconds(1))
                    let newState = Clipboard.state()
                    await MainActor.run {
                        message = result
                        state = newState
                        working = false
                    }
                }
            } label: {
                Text(working ? "Fixing…" : "Fix clipboard").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(working)
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(minHeight: 14)
        }
        .padding(22)
        .frame(width: 280, height: 280)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            state = Clipboard.state()
        }
    }

    private var icon: String {
        switch state {
        case .ok: "checkmark.circle.fill"
        case .strayKey: "exclamationmark.triangle.fill"
        case .handoffOff: "xmark.circle.fill"
        }
    }
    private var tint: Color {
        switch state {
        case .ok: .green
        case .strayKey: .orange
        case .handoffOff: .red
        }
    }
    private var title: String {
        switch state {
        case .ok: "Settings look right"
        case .strayKey: "Clipboard sharing blocked"
        case .handoffOff: "Handoff is off"
        }
    }
    private var detail: String {
        switch state {
        case .ok: "If pasting from your iPhone still fails, Fix restarts the clipboard service."
        case .strayKey(let v): "A leftover \(key) = \(v) setting is overriding Handoff. Fix removes it."
        case .handoffOff: "Turn on System Settings → General → AirDrop & Handoff → Allow Handoff."
        }
    }
}

@main
struct ClipboardFixApp: App {
    var body: some Scene {
        Window("Clipboard Fix", id: "main") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
