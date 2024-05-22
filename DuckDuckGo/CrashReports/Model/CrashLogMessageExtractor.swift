//
//  CrashLogMessageExtractor.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Common
import Foundation
import OSLog // swiftlint:disable:this enforce_os_log_wrapper

struct CrashLogMessageExtractor {

    private struct CrashLog {

        // ""2024-05-22T08:17:23Z59070.log"
        static let fileNameRegex = regex(#"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:[+-][0-2]\d:[0-5]\d|Z))-(\d+)\.log$"#)

        let url: URL
        let timestamp: Date
        let pid: pid_t

        init?(url: URL) {
            let fileName = url.lastPathComponent

            guard let match = Self.fileNameRegex.firstMatch(in: fileName, range: fileName.fullRange),
                  match.numberOfRanges >= 3 else { return nil }

            let dateNsRange = match.range(at: 1)
            let pidNsRange = match.range(at: 2)
            guard dateNsRange.location != NSNotFound, pidNsRange.location != NSNotFound,
                  let dateRange = Range(dateNsRange, in: fileName),
                  let pidRange = Range(pidNsRange, in: fileName),
                  let timestamp = ISO8601DateFormatter().date(from: String(fileName[dateRange])),
                  let pid = pid_t(fileName[pidRange])
            else { return nil }

            self.url = url
            self.timestamp = timestamp
            self.pid = pid
        }
    }

    static func installSignalHandlers() {
        guard #available(macOS 12.0, *) else { return }

        signal(SIGABRT, signalHandler)
        signal(SIGFPE, signalHandler)
        signal(SIGILL, signalHandler)
        signal(SIGSEGV, signalHandler)
        signal(SIGBUS, signalHandler)
        signal(SIGTRAP, signalHandler)
        signal(SIGSYS, signalHandler)
    }

    static func crashLogMessage(for timestamp: Date?, pid: pid_t?) -> String? {
        let fm = FileManager.default
        let diagDir = fm.diagnosticsDirectory
        guard timestamp != nil || pid != nil,
              var crashLogs = try? fm.contentsOfDirectory(atPath: diagDir.path).compactMap({ CrashLog(url: diagDir.appending($0)) }) else { return nil }

        if let pid, pid > 0 {
            // filter by Process Identifier if it‘s known
            crashLogs = crashLogs.filter { $0.pid == pid }
        }

        // sort by distance from the crash timestamp, take the closest
        let timestamp = timestamp ?? Date()
        let crashLog = crashLogs.sorted { (lhs: CrashLog, rhs: CrashLog) in
            abs(timestamp.timeIntervalSince(lhs.timestamp)) < abs(timestamp.timeIntervalSince(rhs.timestamp))
        }.first

        guard let crashLog else {
            os_log("😵 no crash logs found for %{public}s/%d", ISO8601DateFormatter().string(from: timestamp), pid ?? 0)
            return nil
        }
        // allow max of 3s timestamp difference when no pid available
        guard pid != nil || abs(timestamp.timeIntervalSince(crashLog.timestamp)) <= 3 else {
            os_log("😵 closest crashlog %{public}s differs from %{public}s by %dms", crashLog.url.lastPathComponent, ISO8601DateFormatter().string(from: timestamp), abs(timestamp.timeIntervalSince(crashLog.timestamp)))
            return nil
        }

        do {
            let message = try String(contentsOf: crashLog.url)
            return message
        } catch {
            os_log("😵 could not read contents of %{public}s: %s", crashLog.url.lastPathComponent, error.localizedDescription)
            return nil
        }
    }

}

@available(macOS 12.0, *)
func signalHandler(_ sig: Int32) {
    os_log("😵 signalHandler %d", sig)
    defer {
        // pass the signal further to crash
        signal(sig, SIG_DFL)
    }

    // MARK: get crash description message from application log
    let data: Data
    let fm = FileManager.default
    do {
#if APPSTORE
        let store = try OSLogStore(scope: .currentProcessIdentifier)
#else
        let store = try OSLogStore.local()
#endif
        let startDate = Date().addingTimeInterval(-1)
        let categories = ["", "General"]
        let keywords = [/*F|f*/"atal", /*T|t*/"erminat"/*e|ing*/, /*E|e*/"xception", /*A|a*/"ssert"/*ion*/]
        let predicate = NSPredicate(format: """
        date >= %@ AND (composedMessage CONTAINS %@ OR composedMessage CONTAINS %@ OR composedMessage CONTAINS %@ OR composedMessage CONTAINS %@)
        """, startDate as NSDate, keywords[0], keywords[1], keywords[2], keywords[3])

        let entries = try store.getEntries(at: store.position(date: startDate), matching: predicate).compactMap { $0 as? OSLogEntryLog }

        // find last matching entry
        guard let failureEntryIdx = entries.lastIndex(where: { entry in
            entry.date >= startDate
            && categories.contains(entry.category)
            && keywords.contains(where: { keyword in
                entry.composedMessage.contains(keyword)
            })
        }) else { return }
        let match = entries[failureEntryIdx]

        let isRelatedEntry: (OSLogEntryLog) -> Bool = { entry in
            entry.date >= startDate
            && entry.level == match.level
            && entry.subsystem == match.subsystem
            && entry.category == match.category
        }
        // go up looking for the related messages with the same type and category
        let startIndex = (0..<failureEntryIdx).reversed().drop(while: { isRelatedEntry(entries[$0]) }).first.map { $0 + 1 } ?? failureEntryIdx
        // go down looking for the related messages with the same type and category
        let endIndex = (failureEntryIdx + 1 < entries.endIndex) ? ((failureEntryIdx + 1)..<entries.endIndex).drop(while: { isRelatedEntry(entries[$0]) }).startIndex : failureEntryIdx + 1

        // extract the whole exception message
        let message = entries[startIndex..<endIndex].map(\.composedMessage).joined(separator: "\n").sanitized()

        data = message.utf8data

    } catch {
        data = "\(error)".utf8data
    }

    // create App Support/Diagnostics folder
    let diagnosticsUrl = fm.diagnosticsDirectory
    try? fm.createDirectory(at: diagnosticsUrl, withIntermediateDirectories: true)

    // save crash log with `2024-05-20T12:11:33Z-%pid%.log` file name format
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let fileName = "\(timestamp)-\(ProcessInfo().processIdentifier).log"
    do {
        try data.write(to: diagnosticsUrl.appendingPathComponent(fileName))
        os_log("😵 crash log was written to %{public}s – %d bytes", fileName, data.count)
    } catch {
        os_log("😵 failed to save crash log to %{public}s: %{public}s", fileName, error.localizedDescription)
    }
}

private extension FileManager {
    var diagnosticsDirectory: URL {
        applicationSupportDirectoryForComponent(named: "Diagnostics")
    }
}
