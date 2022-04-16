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
import Combine
import os

protocol SaveCredentialsDelegate: AnyObject {

    /// May not be called on main thread.
    func shouldCloseSaveCredentialsViewController(_: SaveCredentialsViewController)

}

final class SaveCredentialsViewController: NSViewController {

    static func create() -> SaveCredentialsViewController {
        let storyboard = NSStoryboard(name: "PasswordManager", bundle: nil)
        let controller: SaveCredentialsViewController = storyboard.instantiateController(identifier: "SaveCredentials")
        controller.loadView()

        return controller
    }

    @IBOutlet var faviconImage: NSImageView!
    @IBOutlet var domainLabel: NSTextField!
    @IBOutlet var usernameField: NSTextField!
    @IBOutlet var hiddenPasswordField: NSSecureTextField!
    @IBOutlet var visiblePasswordField: NSTextField!
    @IBOutlet var notNowButton: NSButton!
    @IBOutlet var saveButton: NSButton!
    @IBOutlet var updateButton: NSButton!
    @IBOutlet var dontUpdateButton: NSButton!
    @IBOutlet var fireproofCheck: NSButton!

    weak var delegate: SaveCredentialsDelegate?

    private var credentials: SecureVaultModels.WebsiteCredentials?

    private var faviconManagement: FaviconManagement = FaviconManager.shared

    private var saveButtonAction: (() -> Void)?

    private var appearanceCancellable: AnyCancellable?

    var passwordData: Data {
        let string = hiddenPasswordField.isHidden ? visiblePasswordField.stringValue : hiddenPasswordField.stringValue
        return string.data(using: .utf8)!
    }

    /// Note that if the credentials.account.id is not nil, then we consider this an update rather than a save.
    func saveCredentials(_ credentials: SecureVaultModels.WebsiteCredentials) {
        self.credentials = credentials
        self.domainLabel.stringValue = credentials.account.domain
        self.usernameField.stringValue = credentials.account.username
        self.hiddenPasswordField.stringValue = String(data: credentials.password, encoding: .utf8) ?? ""
        self.visiblePasswordField.stringValue = self.hiddenPasswordField.stringValue
        self.loadFaviconForDomain(credentials.account.domain)

        notNowButton.isHidden = credentials.account.id != nil
        saveButton.isHidden = credentials.account.id != nil

        updateButton.isHidden = credentials.account.id == nil
        dontUpdateButton.isHidden = credentials.account.id == nil
    }

    @IBAction func onSaveClicked(sender: Any?) {
        defer {
            self.delegate?.shouldCloseSaveCredentialsViewController(self)
        }

        var account = SecureVaultModels.WebsiteAccount(username: usernameField.stringValue.trimmingWhitespaces(),
                                                       domain: domainLabel.stringValue)
        account.id = credentials?.account.id
        let credentials = SecureVaultModels.WebsiteCredentials(account: account, password: passwordData)

        do {
            try SecureVaultFactory.default.makeVault(errorReporter: SecureVaultErrorReporter.shared).storeWebsiteCredentials(credentials)
        } catch {
            os_log("%s:%s: failed to store credentials %s", type: .error, className, #function, error.localizedDescription)
        }

        Pixel.fire(.autofillItemSaved(kind: .password))
        if self.fireproofCheck.state == .on {
            Pixel.fire(.fireproof(kind: .pwm, suggested: .pwm))
            FireproofDomains.shared.add(domain: account.domain)
        }
    }

    @IBAction func onDontUpdateClicked(_ sender: Any) {
        delegate?.shouldCloseSaveCredentialsViewController(self)
    }

    @IBAction func onNotNowClicked(sender: Any?) {
        delegate?.shouldCloseSaveCredentialsViewController(self)

        guard PrivacySecurityPreferences.shared.loginDetectionEnabled else { return }

        guard let window = view.window else {
            os_log("%s: Window is nil", type: .error, className)
            return
        }

        let host = domainLabel.stringValue
        // Don't ask if already fireproofed.
        guard !FireproofDomains.shared.isFireproof(fireproofDomain: host) else { return }

        let alert = NSAlert.fireproofAlert(with: host.dropWWW())
        alert.beginSheetModal(for: window) { response in
            if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                Pixel.fire(.fireproof(kind: .pwm, suggested: .suggested))
                FireproofDomains.shared.add(domain: host)
            }
        }

        Pixel.fire(.fireproofSuggested())
    }

    @IBAction func onTogglePasswordVisibility(sender: Any?) {
        updatePasswordFieldVisibility(visible: !hiddenPasswordField.isHidden)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        appearanceCancellable = view.subscribeForAppApperanceUpdates()
        visiblePasswordField.isHidden = true
        saveButton.becomeFirstResponder()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        updatePasswordFieldVisibility(visible: false)
    }

    func loadFaviconForDomain(_ domain: String) {
        faviconImage.image = faviconManagement.getCachedFavicon(for: domain, sizeCategory: .small)?.image
            ?? NSImage(named: NSImage.Name("Web"))
    }

    private func updatePasswordFieldVisibility(visible: Bool) {
        if visible {
            visiblePasswordField.stringValue = hiddenPasswordField.stringValue
            visiblePasswordField.isHidden = false
            hiddenPasswordField.isHidden = true
        } else {
            hiddenPasswordField.stringValue = visiblePasswordField.stringValue
            hiddenPasswordField.isHidden = false
            visiblePasswordField.isHidden = true
        }
    }

}
