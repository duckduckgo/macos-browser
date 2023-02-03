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

extension NSAlert {

    var stringValue: String? {
        return (accessoryView as? NSTextField)?.stringValue
    }

    static func importFailedAlert(source: DataImport.Source, linkDelegate: NSTextViewDelegate) -> NSAlert {
        let alert = NSAlert()

        let linkText = UserText.dataImportSubmitFeedback
        let informativeText = UserText.dataImportFailedBody

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 250, height: 0))
        textView.applyLabelStyle()

        let attributedString = NSMutableAttributedString(string: informativeText)
        attributedString.addLink("", toText: linkText) // The actual value of the link isn't important, we're reacting to the click via the delegate
        attributedString.addAttributes([
            .font: NSFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor(named: "BlackWhite60")!
        ], range: NSRange(location: 0, length: attributedString.length))

        textView.textStorage?.setAttributedString(attributedString)

        textView.sizeToFit()
        textView.delegate = linkDelegate

        alert.messageText = UserText.dataImportFailedTitle
        alert.accessoryView = textView
        alert.alertStyle = .warning
        alert.addButton(withTitle: UserText.dataImportAlertAccept)

        return alert
    }

    static func passwordRequiredAlert(source: DataImport.Source) -> NSAlert {
        let textField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        let alert = NSAlert()

        alert.messageText = UserText.dataImportRequiresPasswordTitle(source)
        alert.informativeText = UserText.dataImportRequiresPasswordBody(source)
        alert.alertStyle = .warning
        alert.accessoryView = textField
        alert.addButton(withTitle: UserText.dataImportAlertImport)
        alert.addButton(withTitle: UserText.dataImportAlertCancel)

        return alert
    }

    static func failureAlert(message: String) -> NSAlert {
        let alert = NSAlert()

        alert.messageText = UserText.dataImportFailedTitle
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: UserText.dataImportAlertAccept)

        return alert
    }

}
