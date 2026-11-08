import Foundation

enum TimeMachineProbe {
    /// Human line for the Ask-first warning, based on this Mac’s last backup when available.
    static func askFirstWarningMessage() -> String {
        let lead = "You picked items that cannot always be rebuilt."
        let tail = "Back up first if you are unsure."
        if let date = lastBackupDate() {
            let ago = relativeAge(since: date)
            return "\(lead) Your last Time Machine backup was \(ago). \(tail)"
        }
        return "\(lead) No recent Time Machine backup was found on this Mac. \(tail)"
    }

    /// Body copy for the Clean Up confirm sheet.
    static func askConfirmSheetBody() -> String {
        let tail = "Back up first, or continue. Everything still goes to the Trash."
        if let date = lastBackupDate() {
            return "Your last Time Machine backup was \(relativeAge(since: date)). \(tail)"
        }
        return "No recent Time Machine backup was found on this Mac. \(tail)"
    }

    static func lastBackupDate() -> Date? {
        if let fromLatest = dateFromLatestBackupPath() {
            return fromLatest
        }
        return dateFromPreferences()
    }

    private static func dateFromLatestBackupPath() -> Date? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        process.arguments = ["latestbackup"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !path.isEmpty, path != "(null)" else { return nil }

        // Paths look like …/Backups.backupdb/…/2024-10-28-094133
        let name = URL(fileURLWithPath: path).lastPathComponent
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        if let date = formatter.date(from: name) {
            return date
        }
        // Fall back to folder modification date.
        if let values = try? URL(fileURLWithPath: path)
            .resourceValues(forKeys: [.contentModificationDateKey]),
           let modified = values.contentModificationDate {
            return modified
        }
        return nil
    }

    private static func dateFromPreferences() -> Date? {
        let urls = [
            URL(fileURLWithPath: "/Library/Preferences/com.apple.TimeMachine.plist"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Preferences/com.apple.TimeMachine.plist")
        ]
        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
            else { continue }

            if let destinations = plist["Destinations"] as? [[String: Any]] {
                var newest: Date?
                for dest in destinations {
                    let candidates: [Any?] = [
                        dest["LastSuccessfulDate"],
                        dest["SnapshotDates"].flatMap { ($0 as? [Date])?.max() },
                        (dest["SnapshotDates"] as? [Any])?.compactMap { $0 as? Date }.max()
                    ]
                    for value in candidates {
                        if let date = value as? Date {
                            if newest == nil || date > newest! { newest = date }
                        }
                    }
                }
                if let newest { return newest }
            }

            if let date = plist["LastDestinationBackupDate"] as? Date {
                return date
            }
        }
        return nil
    }

    private static func relativeAge(since date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        let days = seconds / 86_400
        if days <= 0 {
            let hours = seconds / 3_600
            if hours <= 0 { return "just now" }
            if hours == 1 { return "1 hour ago" }
            return "\(hours) hours ago"
        }
        if days == 1 { return "1 day ago" }
        if days < 30 { return "\(days) days ago" }
        let months = days / 30
        if months == 1 { return "1 month ago" }
        if months < 12 { return "\(months) months ago" }
        let years = days / 365
        if years <= 1 { return "1 year ago" }
        return "\(years) years ago"
    }
}
