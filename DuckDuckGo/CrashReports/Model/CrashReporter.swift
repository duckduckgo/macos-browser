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

import Common
import Crashes
import Foundation
import PixelKit

final class CrashReporter {

    private let reader = CrashReportReader()
    private lazy var sender = CrashReportSender(platform: .macOS, pixelEvents: CrashReportSender.pixelEvents)
    private lazy var crcidManager = CRCIDManager()
    private lazy var promptPresenter = CrashReportPromptPresenter()

    @UserDefaultsWrapper(key: .lastCrashReportCheckDate, defaultValue: nil)
    private var lastCheckDate: Date?

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

        PixelKit.fire(GeneralPixel.crash)
        PixelKit.fire(GeneralPixel.crashDaily, frequency: .legacyDaily)

        promptPresenter.showPrompt(for: latest) {
            guard let contentData = latest.contentData else {
                assertionFailure("CrashReporter: Can't get the content of the crash report")
                return
            }
            Task {
                let crcid = self.crcidManager.crcid
                let result = await self.sender.send(contentData, crcid: crcid)
                self.crcidManager.handleCrashSenderResult(result: result.result, response: result.response)
            }
        }

#endif

    }
}
