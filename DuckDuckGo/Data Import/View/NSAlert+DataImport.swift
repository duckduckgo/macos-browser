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

    var stringValue: String? {
        return (accessoryView as? NSTextField)?.stringValue
    }

    static func closeRunningBrowserAlert(source: DataImport.Source) -> NSAlert {
        let alert = NSAlert()

        alert.messageText = "Would you like to quit \(source.importSourceName) now?"
        alert.informativeText = "You must quit \(source.importSourceName) before importing data."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit \(source.importSourceName)")
        alert.addButton(withTitle: "Cancel")

        return alert
    }

    static func browserNeedsToBeClosedAlert(source: DataImport.Source) -> NSAlert {
        let alert = NSAlert()

        alert.messageText = "Import Failed"
        alert.informativeText = "Please ensure that \(source.importSourceName) is not running before importing data"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Okay")

        return alert
    }

    static func importFailedAlert(source: DataImport.Source) -> NSAlert {
        let alert = NSAlert()

        alert.messageText = "Import Failed"
        alert.informativeText = "Failed to import data from \(source.importSourceName)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Okay")

        return alert
    }

    static func passwordRequiredAlert(source: DataImport.Source) -> NSAlert {
        let textField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        let alert = NSAlert()

        alert.messageText = "Primary Password Required"
        alert.informativeText = "A primary password is required to import \(source.importSourceName) logins."
        alert.alertStyle = .warning
        alert.accessoryView = textField
        alert.addButton(withTitle: "Import")
        alert.addButton(withTitle: "Cancel")

        return alert
    }

    static func failureAlert(message: String) -> NSAlert {
        let alert = NSAlert()

        alert.messageText = "Import Failed"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Okay")

        return alert
    }

}
