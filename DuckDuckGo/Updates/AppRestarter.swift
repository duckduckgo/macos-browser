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
        let quotedDestinationPath = shellQuotedString(destinationPath)

        let preOpenCmd = "/usr/bin/xattr -d -r com.apple.quarantine \(quotedDestinationPath)"

        let script = """
        (while /bin/kill -0 \(pid) >&/dev/null; do /bin/sleep 0.1; done; \(preOpenCmd); /usr/bin/open \(quotedDestinationPath)) &
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

    private func shellQuotedString(_ string: String) -> String {
        let escapedString = string.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escapedString)'"
    }

}
