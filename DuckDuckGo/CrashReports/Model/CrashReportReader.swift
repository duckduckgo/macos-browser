//
//  CrashReportReader.swift
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

import Foundation

final class CrashReportReader {

    static let displayName = Bundle.main.displayName
    static let vpnExtensionDisplayName = "com.duckduckgo.macos.vpn.network-extension"

    func getCrashReports(since lastCheckDate: Date) -> [CrashReport] {
        var allPaths: [URL]

        do {
            allPaths = try FileManager.default.contentsOfDirectory(at: FileManager.userDiagnosticReports, includingPropertiesForKeys: nil)
        } catch {
            assertionFailure("CrashReportReader: Can't read content of diagnostic reports \(error.localizedDescription)")
            return []
        }

#if NETP_SYSTEM_EXTENSION
        do {
            let systemPaths = try FileManager.default.contentsOfDirectory(at: FileManager.systemDiagnosticReports, includingPropertiesForKeys: nil)
            allPaths.append(contentsOf: systemPaths)
        } catch {
            assertionFailure("Failed to read system crash reports: \(error)")
        }
#endif

        let filteredPaths = allPaths.filter({
            isCrashReportPath($0) && belongsToThisApp($0) && isFile(at: $0, newerThan: lastCheckDate)
        })

        return filteredPaths.compactMap(crashReport(from:))
    }

    private func isCrashReportPath(_ path: URL) -> Bool {
        let validExtensions = [LegacyCrashReport.fileExtension, JSONCrashReport.fileExtension]
        return validExtensions.contains(path.pathExtension)
    }

    private func belongsToThisApp(_ path: URL) -> Bool {
        let hasAppPrefix = path.lastPathComponent.hasPrefix(Self.displayName ?? "DuckDuckGo")
        let hasVPNPrefix = path.lastPathComponent.hasPrefix(Self.vpnExtensionDisplayName)

        return hasAppPrefix || hasVPNPrefix
    }

    private func isFile(at path: URL, newerThan lastCheckDate: Date) -> Bool {
        guard let creationDate = FileManager.default.fileCreationDate(url: path) else {
            assertionFailure("CrashReportReader: Can't get the creation date of the report")
            return true
        }

        return creationDate > lastCheckDate && creationDate < Date()
    }

    private func crashReport(from url: URL) -> CrashReport? {
        switch url.pathExtension {
        case LegacyCrashReport.fileExtension: return LegacyCrashReport(url: url)
        case JSONCrashReport.fileExtension: return JSONCrashReport(url: url)
        default: return nil
        }
    }

}

fileprivate extension FileManager {

    static let userDiagnosticReports: URL = {
        let homeDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        return homeDirectoryURL
            .appendingPathComponent("Library/Logs/DiagnosticReports")
    }()

    static let systemDiagnosticReports: URL = {
        return URL(fileURLWithPath: "/Library/Logs/DiagnosticReports")
    }()

    func fileCreationDate(url: URL) -> Date? {
        let fileAttributes: [FileAttributeKey: Any] = (try? self.attributesOfItem(atPath: url.path)) ?? [:]
        return fileAttributes[.creationDate] as? Date
    }

}
