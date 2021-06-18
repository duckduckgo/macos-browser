//
//  SaveCredentialsViewController.swift
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

import SwiftUI

//final class SaveCredentialsViewController: NSHostingController<SaveCredentialsView> {
//
//    static func create() -> SaveCredentialsViewController {
//        return SaveCredentialsViewController(rootView: SaveCredentialsView())
//    }
//
//}

/*
final class SaveCredentialsViewController: NSViewController {

    static func create() -> SaveCredentialsViewController {
         let storyboard = NSStoryboard(name: "SaveCredentials", bundle: nil)
        // :disable force_cast
         return storyboard.instantiateInitialController() as! SaveCredentialsViewController
        // swiftlint:enable force_cast
    }

    @IBOutlet var faviconImage: NSImageView!
    @IBOutlet var domainLabel: NSTextField!
    @IBOutlet var usernameField: NSTextField!
    @IBOutlet var passwordField: NSSecureTextField!

    var credentials: SecureVaultModels.WebsiteCredentials? {
        didSet {
            guard let credentials = self.credentials else { return }
            self.domainLabel.stringValue = credentials.account.domain
            self.usernameField.stringValue = credentials.account.username
            self.passwordField.stringValue = String(data: credentials.password, encoding: .utf8) ?? ""
        }
    }

    @IBAction func onSaveClicked(sender: Any?) {
    }

    @IBAction func onNotNowClicked(sender: Any?) {
    }

    @IBAction func onNeverClicked(sender: Any?) {
    }

    @IBAction func onTogglePasswordVisibility(sender: Any?) {
        guard let passwordCell = passwordField.cell as? NSSecureTextFieldCell else { return }
        print("***", #function, passwordCell.echosBullets)
        let value = passwordField.stringValue
        passwordCell.echosBullets = !passwordCell.echosBullets
        passwordField.stringValue = value
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        print("***", #function)
    }

}
*/
