import Foundation

/// Debug logger that writes to /tmp/quackpilot.log — unified logging swallows
/// NSLog from some Swift contexts on recent macOS, so this is a foolproof
/// fallback while diagnosing permission/scheduling issues.
enum Log {
    private static let url = URL(fileURLWithPath: "/tmp/quackpilot.log")
    private static let lock = NSLock()

    static func write(_ message: String, file: String = #fileID, line: Int = #line) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let entry = "\(stamp) \(file):\(line) — \(message)\n"
        guard let data = entry.data(using: .utf8) else { return }
        lock.lock(); defer { lock.unlock() }
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.close()
            }
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }
}
