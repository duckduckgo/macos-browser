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

    @IBOutlet var titleLabel: NSTextField!
    @IBOutlet var faviconImage: NSImageView!
    @IBOutlet var domainLabel: NSTextField!
    @IBOutlet var usernameField: NSTextField!
    @IBOutlet var hiddenPasswordField: NSSecureTextField!
    @IBOutlet var visiblePasswordField: NSTextField!
    
    @IBOutlet var notNowButton: NSButton!
    @IBOutlet var saveButton: NSButton!
    @IBOutlet var updateButton: NSButton!
    @IBOutlet var dontUpdateButton: NSButton!
    @IBOutlet var doneButton: NSButton!
    @IBOutlet var editButton: NSButton!
    
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
    func update(credentials: SecureVaultModels.WebsiteCredentials, automaticallySaved: Bool) {
        self.credentials = credentials
        self.domainLabel.stringValue = credentials.account.domain
        self.usernameField.stringValue = credentials.account.username
        self.hiddenPasswordField.stringValue = String(data: credentials.password, encoding: .utf8) ?? ""
        self.visiblePasswordField.stringValue = self.hiddenPasswordField.stringValue
        self.loadFaviconForDomain(credentials.account.domain)
        
        fireproofCheck.state = FireproofDomains.shared.isFireproof(fireproofDomain: credentials.account.domain) ? .on : .off
        
        // Only use the non-editable state if a credential was automatically saved and it didn't already exist.
        let condition = credentials.account.id != nil && !credentials.account.username.isEmpty && automaticallySaved 
        updateViewState(editable: !condition)
    }
    
    private func updateViewState(editable: Bool) {
        usernameField.setEditable(editable)
        hiddenPasswordField.setEditable(editable)
        visiblePasswordField.setEditable(editable)

        if editable {
            notNowButton.isHidden = credentials?.account.id != nil
            saveButton.isHidden = credentials?.account.id != nil
            updateButton.isHidden = credentials?.account.id == nil
            dontUpdateButton.isHidden = credentials?.account.id == nil
            
            editButton.isHidden = true
            doneButton.isHidden = true
            
            titleLabel.stringValue = UserText.pmSaveCredentialsEditableTitle
            usernameField.makeMeFirstResponder()
        } else {
            notNowButton.isHidden = true
            saveButton.isHidden = true
            updateButton.isHidden = true
            dontUpdateButton.isHidden = true

            editButton.isHidden = false
            doneButton.isHidden = false
            
            titleLabel.stringValue = UserText.pmSaveCredentialsNonEditableTitle
            view.window?.makeFirstResponder(nil)
        }
    }

    @IBAction func onSaveClicked(sender: Any?) {
        defer {
            self.delegate?.shouldCloseSaveCredentialsViewController(self)
        }

        var account = SecureVaultModels.WebsiteAccount(username: usernameField.stringValue.trimmingWhitespace(),
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
        } else {
            // If the Fireproof checkbox has been unchecked, and the domain is Fireproof, then un-Fireproof it.
            guard FireproofDomains.shared.isFireproof(fireproofDomain: account.domain) else { return }
            FireproofDomains.shared.remove(domain: account.domain)
        }
    }

    @IBAction func onDontUpdateClicked(_ sender: Any) {
        delegate?.shouldCloseSaveCredentialsViewController(self)
    }

    @IBAction func onNotNowClicked(sender: Any?) {
        func notifyDelegate() {
            delegate?.shouldCloseSaveCredentialsViewController(self)
        }

        guard PrivacySecurityPreferences.shared.loginDetectionEnabled else {
            notifyDelegate()
            return
        }

        guard let window = view.window else {
            os_log("%s: Window is nil", type: .error, className)
            notifyDelegate()
            return
        }

        let host = domainLabel.stringValue
        // Don't ask if already fireproofed.
        guard !FireproofDomains.shared.isFireproof(fireproofDomain: host) else {
            notifyDelegate()
            return
        }

        let alert = NSAlert.fireproofAlert(with: host.droppingWwwPrefix())
        alert.beginSheetModal(for: window) { response in
            if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                Pixel.fire(.fireproof(kind: .pwm, suggested: .suggested))
                FireproofDomains.shared.add(domain: host)
            }
            notifyDelegate()
        }

        Pixel.fire(.fireproofSuggested())
    }
    
    @IBAction func onEditClicked(sender: Any?) {
        updateViewState(editable: true)
    }
    
    @IBAction func onDoneClicked(sender: Any?) {
        delegate?.shouldCloseSaveCredentialsViewController(self)
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
