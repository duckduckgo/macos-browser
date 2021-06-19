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

final class SaveCredentialsViewController: NSViewController {

    static func create() -> SaveCredentialsViewController {
        let storyboard = NSStoryboard(name: "SaveCredentials", bundle: nil)
        // swiftlint:disable force_cast
        let controller = storyboard.instantiateInitialController() as! SaveCredentialsViewController
        controller.loadView()
        // swiftlint:enable force_cast
        return controller
    }

    @IBOutlet var faviconImage: NSImageView!
    @IBOutlet var domainLabel: NSTextField!
    @IBOutlet var usernameField: NSTextField!
    @IBOutlet var hiddenPasswordField: NSSecureTextField!
    @IBOutlet var visiblePasswordField: NSTextField!

    var credentials: SecureVaultModels.WebsiteCredentials? {
        didSet {
            guard let credentials = self.credentials else { return }
            self.domainLabel.stringValue = credentials.account.domain
            self.usernameField.stringValue = credentials.account.username
            self.hiddenPasswordField.stringValue = String(data: credentials.password, encoding: .utf8) ?? ""
            self.visiblePasswordField.stringValue = self.hiddenPasswordField.stringValue
            self.loadFaviconForDomain(credentials.account.domain)
        }
    }

    @IBAction func onSaveClicked(sender: Any?) {
    }

    @IBAction func onNotNowClicked(sender: Any?) {
    }

    @IBAction func onNeverClicked(sender: Any?) {
    }

    @IBAction func onTogglePasswordVisibility(sender: Any?) {

        if hiddenPasswordField.isHidden {
            hiddenPasswordField.stringValue = visiblePasswordField.stringValue
            hiddenPasswordField.isHidden = false
            visiblePasswordField.isHidden = true
        } else {
            visiblePasswordField.stringValue = hiddenPasswordField.stringValue
            visiblePasswordField.isHidden = false
            hiddenPasswordField.isHidden = true
        }

    }

    override func viewDidLoad() {
        super.viewDidLoad()
        print("***", #function)
        visiblePasswordField.isHidden = true
    }

    func loadFaviconForDomain(_ domain: String) {
        faviconImage.image = LocalFaviconService.shared.getCachedFavicon(for: domain, mustBeFromUserScript: false)
            ?? NSImage(named: NSImage.Name("Web"))
    }

}
