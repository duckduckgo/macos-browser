//
//  NSAlert+DataImport.swift
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

extension NSAlert {

    static func closeRunningBrowserAlert(source: DataImport.Source) -> NSAlert {
        let alert = NSAlert()

        alert.icon = source.importSourceImage
        alert.messageText = "Close Browser"
        alert.informativeText = "\(source.importSourceName) must be closed before importing data. Would you like to close it now?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Close Browser")
        alert.addButton(withTitle: "Cancel")

        return alert
    }

    static func importFailedAlert(source: DataImport.Source) -> NSAlert {
        let alert = NSAlert()

        alert.icon = source.importSourceImage
        alert.messageText = "Import Failed"
        alert.informativeText = "Please ensure that \(source.importSourceName) is not running before importing data"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Okay")

        return alert
    }

}
