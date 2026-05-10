import AppKit
import EventKit
import Foundation

var outputPath: String? = nil
if let idx = CommandLine.arguments.firstIndex(of: "--output"),
   idx + 1 < CommandLine.arguments.count {
    outputPath = CommandLine.arguments[idx + 1]
}

func emit(_ string: String) {
    if let path = outputPath {
        try? string.write(toFile: path, atomically: true, encoding: .utf8)
    } else {
        print(string)
    }
}

func requestAndRun(_ store: EKEventStore, completion: @escaping () -> Void) {
    if #available(macOS 14.0, *) {
        store.requestFullAccessToEvents { granted, _ in
            if granted { printEvents(store) } else { emit("{\"error\":\"denied\"}") }
            completion()
        }
    } else {
        store.requestAccess(to: .event) { granted, _ in
            if granted { printEvents(store) } else { emit("{\"error\":\"denied\"}") }
            completion()
        }
    }
}

if let idx = CommandLine.arguments.firstIndex(of: "--open"),
   idx + 1 < CommandLine.arguments.count,
   let epoch = Int(CommandLine.arguments[idx + 1]) {
    let offset = epoch - Int(Date().timeIntervalSince1970)
    let script = """
    tell application "Calendar"
        activate
    end tell
    delay 0.5
    tell application "Calendar"
        view calendar at ((current date) + \(offset))
        switch view to day view
    end tell
    """
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    proc.arguments = ["-e", script]
    try? proc.run()
    proc.waitUntilExit()
    exit(0)
}

if outputPath != nil {
    // Launched via `open -W` — need NSApplication for lifecycle tracking + TCC prompt
    class AppDelegate: NSObject, NSApplicationDelegate {
        func applicationDidFinishLaunching(_ notification: Notification) {
            requestAndRun(EKEventStore()) { NSApplication.shared.terminate(nil) }
        }
    }
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
} else {
    // Direct invocation — fast path with semaphore
    let store = EKEventStore()
    let sem = DispatchSemaphore(value: 0)
    requestAndRun(store) { sem.signal() }
    sem.wait()
}

func printEvents(_ store: EKEventStore) {
    let dayOffset: Int = {
        for arg in CommandLine.arguments.dropFirst() {
            if arg.hasPrefix("-") { continue }
            if let n = Int(arg) { return n }
        }
        return 0
    }()

    let cal = Calendar.current
    let target = cal.date(byAdding: .day, value: dayOffset, to: Date())!
    let start = dayOffset == 0 ? Date() : cal.startOfDay(for: target)
    let end = cal.date(bySettingHour: 23, minute: 59, second: 59, of: target)!

    let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
    let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

    let fmt = DateFormatter()
    fmt.dateFormat = "HH:mm"

    var results: [[String: String]] = []
    for event in events {
        results.append([
            "title": event.title ?? "(no title)",
            "start": fmt.string(from: event.startDate),
            "end": fmt.string(from: event.endDate),
            "location": event.location ?? "",
            "calendar": event.calendar.title,
            "epoch": String(Int(event.startDate.timeIntervalSince1970)),
        ])
    }

    if let data = try? JSONSerialization.data(withJSONObject: results),
       let json = String(data: data, encoding: .utf8) {
        emit(json)
    } else {
        emit("[]")
    }
}
