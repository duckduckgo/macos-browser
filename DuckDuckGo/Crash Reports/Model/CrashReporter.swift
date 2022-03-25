//
//  CrashReporter.swift
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

final class CrashReporter {

    private let reader = CrashReportReader()
    private lazy var sender = CrashReportSender()
    private lazy var promptPresenter = CrashReportPromptPresenter()

    @UserDefaultsWrapper(key: .lastCrashReportCheckDate, defaultValue: nil)
    private var lastCheckDate: Date?

    private var latestCrashReport: CrashReport?

    func checkForNewReports() {

#if !DEBUG

        guard let lastCheckDate = lastCheckDate else {
            // Initial run
            self.lastCheckDate = Date()
            return
        }

        let crashReports = reader.getCrashReports(since: lastCheckDate)
        self.lastCheckDate = Date()

        guard let latest = crashReports.last else {
            // No new crash report
            return
        }

        Pixel.fire(.crash)

        latestCrashReport = latest
        promptPresenter.showPrompt(self, for: latest)

#endif

    }

}

extension CrashReporter: CrashReportPromptViewControllerDelegate {

    func crashReportPromptViewController(_ crashReportPromptViewController: CrashReportPromptViewController,
                                         userDidAllowToReport: Bool) {
        guard userDidAllowToReport else {
            return
        }

        guard let latestCrashReport = latestCrashReport else {
            assertionFailure("CrashReporter: The latest crash report is nil")
            return
        }

        sender.send(latestCrashReport)
    }

}
