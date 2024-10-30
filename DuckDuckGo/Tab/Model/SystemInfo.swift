//
//  SystemInfo.swift
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

import Foundation
import Common

#if !APPSTORE

final class SystemInfo {

    static func pixelParameters(appVersion: AppVersion = AppVersion.shared) async -> [String: String] {
        let availableMemoryPercent = Self.getAvailableMemoryPercent()
        let availableDiskSpacePercent = Self.getAvailableDiskSpacePercent()
        return [
           "available_memory": String(availableMemoryPercent),
           "available_diskspace": String(format: "%.2f", availableDiskSpacePercent),
           "os_version": appVersion.osVersion,
        ]
    }

    static func getAvailableMemoryPercent() -> Int {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/memory_pressure")

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Should be the last line, but just in case search for it explicitly
                let lines = output.split(separator: "\n")
                if let memoryLine = lines.first(where: { $0.contains("System-wide memory free percentage") }),
                   let range = memoryLine.range(of: "\\d+", options: .regularExpression),
                   let percentage = Int(memoryLine[range]) {
                    return percentage
                }
            }
        } catch {
            assertionFailure("Unable to run memory_pressure")
        }

        return -1
    }

    static func getAvailableDiskSpacePercent() -> Double {
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let totalSpace = attributes[.systemSize] as? UInt64,
              let freeSpace = attributes[.systemFreeSize] as? UInt64 else {
                return -1.0
              }

        return Double(freeSpace) / Double(totalSpace) * 100
    }

}

#endif
