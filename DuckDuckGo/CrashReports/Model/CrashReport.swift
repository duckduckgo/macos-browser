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
        let crashLogMessage = CrashLogMessageExtractor.crashLogMessage(for: timestamp, pid: pid).flatMap { message in
            message.replacingOccurrences(of: "\n", with: "\\n") // escape newlines
        }
        if let crashLogMessage, !crashLogMessage.isEmpty {
            fileContents = "Message: " + crashLogMessage + "\n" + fileContents
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

        // append crash log message if loaded
        let pid = fileContents.firstMatch(of: Self.pidRegex)?.range(at: 1, in: fileContents).flatMap { pid_t(fileContents[$0]) }
        let timestamp = fileContents.firstMatch(of: Self.timestampRegex)?.range(at: 1, in: fileContents).flatMap {
            Self.dateFormatter.date(from: String(fileContents[$0]))
        }
        let crashLogMessage = CrashLogMessageExtractor.crashLogMessage(for: timestamp, pid: pid).flatMap { message in
            try? JSONSerialization.data(withJSONObject: message, options: .fragmentsAllowed).utf8String() // escape for json
        }
        if let openBraceIdx = fileContents.firstIndex(of: "{"), let crashLogMessage, !crashLogMessage.isEmpty {
            let json = "\"message\": \(crashLogMessage),"
            fileContents.insert(contentsOf: json, at: fileContents.index(after: openBraceIdx))
        }

        return fileContents
    }()

    var contentData: Data? {
        content?.data(using: .utf8)
    }

}

@available(macOS 12, *)
extension CrashCollection {

    func startAttachingCrashLogMessages(didFindCrashReports: @escaping (_ pixelParameters: [[String: String]], _ payloads: [Data], _ uploadReports: @escaping () -> Void) -> Void) {
        start(process: { payloads in
            payloads.compactMap { payload in
                var dict = payload.dictionaryRepresentation()

                var pid: pid_t?
                if #available(macOS 14.0, *) {
                    pid = payload.crashDiagnostics?.first?.metaData.pid
                }
                var crashDiagnostics = dict["crashDiagnostics"] as? [[AnyHashable: Any]] ?? []
                var crashDiagnosticsDict = crashDiagnostics.first ?? [:]
                var diagnosticMetaDataDict = crashDiagnosticsDict["diagnosticMetaData"] as? [AnyHashable: Any] ?? [:]
                var objCexceptionReason = diagnosticMetaDataDict["objectiveCexceptionReason"] as? [AnyHashable: Any] ?? [:]

                var exceptionMessage = (objCexceptionReason["composedMessage"] as? String)?.sanitized()

                // append crash log message if loaded
                if let crashInfo = CrashLogMessageExtractor.crashLogMessage(for: payload.timeStampBegin, pid: pid), !crashInfo.isEmpty {
                    if let existingMessage = exceptionMessage, !existingMessage.isEmpty {
                        exceptionMessage = existingMessage + "\n\n---\n\n" + crashInfo
                    } else {
                        exceptionMessage = crashInfo
                    }
                }

                objCexceptionReason["composedMessage"] = exceptionMessage
                diagnosticMetaDataDict["objectiveCexceptionReason"] = objCexceptionReason
                crashDiagnosticsDict["diagnosticMetaData"] = diagnosticMetaDataDict
                crashDiagnostics[0] = crashDiagnosticsDict
                dict["crashDiagnostics"] = crashDiagnostics

                guard JSONSerialization.isValidJSONObject(dict) else {
                    assertionFailure("Invalid JSON object: \(dict)")
                    return nil
                }
                return try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
            }

        }, didFindCrashReports: didFindCrashReports)
    }

}

struct CrashDataPayload: CrashReportPresenting {
    let data: Data

    var content: String? {
        data.utf8String()
    }
}
