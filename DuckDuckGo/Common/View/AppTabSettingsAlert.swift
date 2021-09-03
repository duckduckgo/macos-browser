//
//  AppTabSettingsAlert.swift
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

final class AppTabSettingsAlert: NSAlert {

    let appNameTextField: NSTextField

    private var okButton: NSButton!

    private let defaultIcon: NSImage

    var imageView: NSImageView? {
        okButton.superview!.subviews.first(where: { $0 is NSImageView }) as? NSImageView
    }

    init(suggestedName: String, icon: NSImage?) {
        appNameTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        appNameTextField.setAccessibilityLabel("App Name")
        appNameTextField.placeholderString = "App Name"
        appNameTextField.isAutomaticTextCompletionEnabled = false
        appNameTextField.stringValue = suggestedName
        
        defaultIcon = icon ?? .emptyAppIcon

        super.init()

        self.messageText = "Make Web App"
        self.informativeText = "Enter App Name and Drag&Drop another Icon if needed"

        appNameTextField.delegate = self
        appNameTextField.delegate = self

        okButton = addButton(withTitle: UserText.ok)
        okButton.tag = NSApplication.ModalResponse.OK.rawValue

        let cancelButton = addButton(withTitle: UserText.cancel)
        cancelButton.tag = NSApplication.ModalResponse.cancel.rawValue

        self.accessoryView = appNameTextField
        self.icon = defaultIcon

        self.imageView?.isEditable = true

        updateButtons()
    }

    func updateButtons() {
        okButton.isEnabled = !appNameTextField.stringValue.isEmpty
    }

}

extension AppTabSettingsAlert: NSTextFieldDelegate {

    func controlTextDidChange(_ obj: Notification) {
        updateButtons()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        updateButtons()
    }

}
