import Foundation
import AppKit

/// Photos category = `~/Pictures` only (System Settings / Finder).
/// Never touches `Photos Library.photoslibrary` — that triggers the Photos TCC prompt.
enum PhotosSizer {
    private static let cacheKey = "iclearer.picturesFolderBytes"
    private static let cacheDateKey = "iclearer.picturesFolderBytesDate"

    private static var picturesPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures").path
    }

    /// Size of `~/Pictures` via Finder. May show the Automation “Allow” dialog.
    static func measure(onAwaitingAllow: (() -> Void)? = nil) -> Int64 {
        let path = picturesPath
        guard FileManager.default.fileExists(atPath: path) else { return 0 }

        // Tell the UI before Finder Automation may block on “Allow”.
        onAwaitingAllow?()
        let best = finderFolderSize(at: path)

        if best > 0 {
            UserDefaults.standard.set(best, forKey: cacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cacheDateKey)
            return best
        }

        if let cached = UserDefaults.standard.object(forKey: cacheKey) as? Int64, cached > 0 {
            let age = Date().timeIntervalSince1970 - UserDefaults.standard.double(forKey: cacheDateKey)
            if age < 7 * 24 * 3600 { return cached }
        }
        return 0
    }

    private static func finderFolderSize(at path: String) -> Int64 {
        guard FileManager.default.fileExists(atPath: path) else { return 0 }
        let escaped = path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "Finder"
          try
            set p to (POSIX file "\(escaped)") as alias
            set s to size of p
            if s is missing value then return "0"
            return (s as integer) as string
          on error
            return "0"
          end try
        end tell
        """
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return 0 }
        let result = script.executeAndReturnError(&error)
        if error != nil { return 0 }
        if let text = result.stringValue, let parsed = Int64(text), parsed > 0 {
            return parsed
        }
        let asDouble = Int64(result.doubleValue)
        if asDouble > 0 { return asDouble }
        let as32 = Int64(result.int32Value)
        return as32 > 0 ? as32 : 0
    }
}
