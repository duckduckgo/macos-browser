//
//  CrashReport.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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
import Crashes
import Foundation
import MetricKit

protocol CrashReportPresenting {
    var content: String? { get }
}

protocol CrashReport: CrashReportPresenting {

    static var fileExtension: String { get }

    var url: URL { get }
    var contentData: Data? { get }

}

final class LegacyCrashReport: CrashReport {

    static let fileExtension = "crash"

    private static let headerItemsToFilter = [
        "Anonymous UUID:",
        "Sleep/Wake UUID:"
    ]
    private static let pidRegex = regex(#"^Process:.*\[(\d+)\]$"#)
    private static let timestampRegex = regex(#"Date\/Time:\s+(.+)\s*$"#)
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS Z"
        return formatter
    }()

    let url: URL

    init(url: URL) {
        self.url = url
    }

    lazy var content: String? = {
        guard var fileContents = try? String(contentsOf: url)
            .components(separatedBy: "\n")
            .filter({ line in
                for headerItemToFilter in Self.headerItemsToFilter where line.hasPrefix(headerItemToFilter) {
                    return false
                }
                return true
            })
            .joined(separator: "\n") else { return nil }

        // prepend crash log message if loaded
        let pid = fileContents.firstMatch(of: Self.pidRegex)?.range(at: 1, in: fileContents).flatMap { pid_t(fileContents[$0]) }
        let timestamp = fileContents.firstMatch(of: Self.timestampRegex)?.range(at: 1, in: fileContents).flatMap {
            Self.dateFormatter.date(from: String(fileContents[$0]))
        }
        if let diagnostic = try? CrashLogMessageExtractor().crashDiagnostic(for: timestamp, pid: pid)?.diagnosticData(), !diagnostic.isEmpty,
           let message = try? JSONEncoder().encode(diagnostic).utf8String()?.replacingOccurrences(of: "\n", with: "\\n") {
            fileContents = "Message: " + message + "\n" + fileContents
        }

        return fileContents
    }()

    var contentData: Data? {
        content?.data(using: .utf8)
    }

}

final class JSONCrashReport: CrashReport {

    static let fileExtension = "ips"

    private static let headerItemsToFilter = [
        "sleepWakeUUID",
        "deviceIdentifierForVendor",
        "rolloutId"
    ]
    private static let pidRegex = regex(#""pid"\s*:\s*(\d+)(?:,|$)"#)
    private static let timestampRegex = regex(#""timestamp"\s*:\s*"([^"]+)""#)
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SS Z"
        return formatter
    }()

    let url: URL

    init(url: URL) {
        self.url = url
    }

    lazy var content: String? = {
        guard var fileContents = try? String(contentsOf: self.url) else { return nil }

        for itemToFilter in Self.headerItemsToFilter {
            let patternToReplace = "\"\(itemToFilter)\"\\s*:\\s*\"[^\"]*\""
            let redactedKeyValuePair = "\"\(itemToFilter)\":\"<removed>\""

            fileContents = fileContents.replacingOccurrences(of: patternToReplace, with: redactedKeyValuePair, options: .regularExpression)
        }

        // append crash log message and stack trace if loaded
        let pid = fileContents.firstMatch(of: Self.pidRegex)?.range(at: 1, in: fileContents).flatMap { pid_t(fileContents[$0]) }
        let timestamp = fileContents.firstMatch(of: Self.timestampRegex)?.range(at: 1, in: fileContents).flatMap {
            Self.dateFormatter.date(from: String(fileContents[$0]))
        }
        if let diagnostic = try? CrashLogMessageExtractor().crashDiagnostic(for: timestamp, pid: pid)?.diagnosticData(), !diagnostic.isEmpty,
           let json = try? JSONEncoder().encode(diagnostic).utf8String()?.trimmingCharacters(in: CharacterSet(charactersIn: "{}")),
           let openBraceIdx = fileContents.firstIndex(of: "{") {
                // insert `"message": "…", "stackTrace": […],` json part after the first `{` in the report
               fileContents.insert(contentsOf: json + ",", at: fileContents.index(after: openBraceIdx))
        }

        return fileContents
    }()

    var contentData: Data? {
        content?.data(using: .utf8)
    }

}

struct CrashDataPayload: CrashReportPresenting {
    let data: Data

    var content: String? {
        data.utf8String()
    }
}
