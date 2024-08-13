//
//  AppRestarter.swift
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

protocol AppRestarting {

    func restart()

}

final class AppRestarter: AppRestarting {

    func restart() {
        let pid = ProcessInfo.processInfo.processIdentifier
        let destinationPath = Bundle.main.bundlePath

        guard isValidApplicationBundle(at: destinationPath) else {
            print("Invalid destination path")
            return
        }

        let preOpenCmd = "/usr/bin/xattr -d -r com.apple.quarantine \(shellQuotedString(destinationPath))"
        let openCmd = "/usr/bin/open \(shellQuotedString(destinationPath))"

        let script = """
        (while /bin/kill -0 \(pid) >&/dev/null; do /bin/sleep 0.1; done; \(preOpenCmd); \(openCmd)) &
        """

        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", script]

        do {
            try task.run()
        } catch {
            print("Unable to launch the task: \(error)")
            return
        }

        // Terminate the current app instance
        exit(0)
    }

    private func isValidApplicationBundle(at path: String) -> Bool {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
        let isAppBundle = path.hasSuffix(".app") && isDirectory.boolValue
        return exists && isAppBundle
    }

    private func shellQuotedString(_ string: String) -> String {
        // Validate that the string is a valid file path
        guard isValidFilePath(string) else {
            fatalError("Invalid file path")
        }
        let escapedString = string.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escapedString)'"
    }

    private func isValidFilePath(_ path: String) -> Bool {
        // Perform validation to ensure the path is a valid and safe file path
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: path)
    }

}
