//
//  NSAlert+ActiveDownloadsTermination.swift
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

import Cocoa

extension NSAlert {

    static func activeDownloadsTerminationAlert(for downloads: Set<WebKitDownloadTask>) -> NSAlert {
        assert(!downloads.isEmpty)

        let activeDownload = downloads.first(where: { $0.state.isDownloading })
        let firstFileName = activeDownload?.state.destinationFilePresenter?.url?.lastPathComponent
            .truncated(length: MainMenu.Constants.maxTitleLength, middle: "…") ?? ""
        let andOthers = downloads.count > 1 ? UserText.downloadsActiveAlertMessageAndOthers : ""
        let thisTheseFiles = downloads.count > 1 ? UserText.downloadsActiveAlertMessageTheseFiles : UserText.downloadsActiveAlertMessageThisFile

        let alert = NSAlert()
        alert.messageText = UserText.downloadsActiveAlertTitle
        alert.informativeText = String(format: UserText.downloadsActiveAlertMessageFormat, firstFileName, andOthers, thisTheseFiles)
        alert.addButton(withTitle: UserText.quit, response: .OK)
        alert.addButton(withTitle: UserText.dontQuit, response: .cancel, keyEquivalent: .escape)

        return alert
    }

    static func activeDownloadsFireWindowClosingAlert(for downloads: Set<WebKitDownloadTask>) -> NSAlert {
        assert(!downloads.isEmpty)

        let activeDownload = downloads.first(where: { $0.state.isDownloading })
        let firstFileName = activeDownload?.state.destinationFilePresenter?.url?.lastPathComponent
            .truncated(length: MainMenu.Constants.maxTitleLength, middle: "…") ?? ""
        let andOthers = downloads.count > 1 ? UserText.downloadsActiveAlertMessageAndOthers : ""
        let thisTheseFiles = downloads.count > 1 ? UserText.downloadsActiveAlertMessageTheseFiles : UserText.downloadsActiveAlertMessageThisFile

        let alert = NSAlert()
        alert.messageText = UserText.downloadsActiveAlertTitle
        alert.informativeText = String(format: UserText.downloadsActiveInFireWindowAlertMessageFormat, firstFileName, andOthers, thisTheseFiles)
        alert.addButton(withTitle: UserText.close, response: .OK)
        alert.addButton(withTitle: UserText.dontClose, response: .cancel, keyEquivalent: .escape)

        return alert
    }

}
