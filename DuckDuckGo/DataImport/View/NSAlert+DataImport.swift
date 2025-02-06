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

import AppKit
import BrowserServicesKit

extension NSAlert {

    var stringValue: String? {
        return (accessoryView as? NSTextField)?.stringValue
    }

    static func passwordRequiredAlert(source: DataImport.Source) -> NSAlert {
        let textField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        let alert = NSAlert()

        alert.messageText = UserText.dataImportRequiresPasswordTitle(source)
        alert.informativeText = UserText.dataImportRequiresPasswordBody(source)
        alert.alertStyle = .warning
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField
        alert.addButton(withTitle: UserText.dataImportAlertImport)
        alert.addButton(withTitle: UserText.dataImportAlertCancel)

        return alert
    }

}
