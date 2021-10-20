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

        let activeDownload = downloads.first(where: { $0.location.destinationURL != nil })
        let firstFileName = activeDownload?.location.destinationURL?.lastPathComponent ?? activeDownload?.suggestedFilename ?? ""
        let andOthers = downloads.count > 1 ? UserText.downloadsActiveAlertMessageAndOthers : ""

        let alert = NSAlert()
        alert.messageText = UserText.downloadsActiveAlertTitle
        alert.informativeText = String(format: UserText.downloadsActiveAlertMessageFormat, firstFileName, andOthers)
        alert.addButton(withTitle: UserText.quit).tag = NSApplication.ModalResponse.OK.rawValue
        alert.addButton(withTitle: UserText.dontQuit).tag = NSApplication.ModalResponse.cancel.rawValue

        return alert
    }

}
