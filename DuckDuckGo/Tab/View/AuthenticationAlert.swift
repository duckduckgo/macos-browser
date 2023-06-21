//
//  AuthenticationAlert.swift
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

final class AuthenticationAlert: NSAlert {

    let usernameTextField: NSTextField
    let passwordTextField: NSSecureTextField

    private var loginButton: NSButton!

    init(host: String, isEncrypted: Bool) {
        let stackView = NSStackView(frame: NSRect(x: 0, y: 0, width: 200, height: 48))
        stackView.orientation = .vertical
        stackView.spacing = 4.0

        usernameTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        usernameTextField.setAccessibilityLabel(UserText.authAlertUsernamePlaceholder)
        usernameTextField.placeholderString = UserText.authAlertUsernamePlaceholder
        usernameTextField.isAutomaticTextCompletionEnabled = false

        stackView.addView(usernameTextField, in: .top)

        passwordTextField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 56))
        passwordTextField.setAccessibilityLabel(UserText.authAlertPasswordPlaceholder)
        passwordTextField.placeholderString = UserText.authAlertPasswordPlaceholder
        passwordTextField.isAutomaticTextCompletionEnabled = false
        stackView.addView(passwordTextField, in: .top)

        super.init()

        self.messageText = UserText.authAlertTitle
        if isEncrypted {
            self.informativeText = String(format: UserText.authAlertEncryptedConnectionMessageFormat, host)
        } else {
            self.informativeText = String(format: UserText.authAlertPlainConnectionMessageFormat, host)
        }

        usernameTextField.nextKeyView = passwordTextField
        loginButton = addButton(withTitle: UserText.authAlertLogInButtonTitle)
        loginButton.tag = NSApplication.ModalResponse.OK.rawValue

        let cancelButton = addButton(withTitle: UserText.cancel)
        cancelButton.tag = NSApplication.ModalResponse.cancel.rawValue

        self.accessoryView = stackView
    }
}
