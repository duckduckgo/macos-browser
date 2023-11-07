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
import Common

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
    @IBOutlet var passwordManagerTitle: NSView!
    @IBOutlet var passwordManagerAccountLabel: NSTextField!
    @IBOutlet var unlockPasswordManagerTitle: NSView!
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
    @IBOutlet var openPasswordManagerButton: NSButton!
    @IBOutlet weak var passwordManagerNotNowButton: NSButton!

    @IBOutlet var fireproofCheck: NSButton!

    weak var delegate: SaveCredentialsDelegate?

    private var credentials: SecureVaultModels.WebsiteCredentials?

    private var faviconManagement: FaviconManagement = FaviconManager.shared

    private var passwordManagerCoordinator = PasswordManagerCoordinator.shared

    private var passwordManagerStateCancellable: AnyCancellable?

    private var saveButtonAction: (() -> Void)?

    var passwordData: Data {
        let string = hiddenPasswordField.isHidden ? visiblePasswordField.stringValue : hiddenPasswordField.stringValue
        return string.data(using: .utf8)!
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        visiblePasswordField.isHidden = true
        saveButton.becomeFirstResponder()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        updatePasswordFieldVisibility(visible: false)

        subscribeToPasswordManagerState()
    }

    override func viewWillDisappear() {
        passwordManagerStateCancellable = nil
    }

    /// Note that if the credentials.account.id is not nil, then we consider this an update rather than a save.
    func update(credentials: SecureVaultModels.WebsiteCredentials, automaticallySaved: Bool) {
        self.credentials = credentials
        self.domainLabel.stringValue = credentials.account.domain ?? ""
        self.usernameField.stringValue = credentials.account.username ?? ""
        self.hiddenPasswordField.stringValue = String(data: credentials.password ?? Data(), encoding: .utf8) ?? ""
        self.visiblePasswordField.stringValue = self.hiddenPasswordField.stringValue
        self.loadFaviconForDomain(credentials.account.domain)

        if let domain = credentials.account.domain, FireproofDomains.shared.isFireproof(fireproofDomain: domain) {
            fireproofCheck.state = .on
        } else {
            fireproofCheck.state = .off
        }

        // Only use the non-editable state if a credential was automatically saved and it didn't already exist.
        let condition = credentials.account.id != nil && !(credentials.account.username?.isEmpty ?? true) && automaticallySaved
        updateViewState(editable: !condition)
    }

    private func updateViewState(editable: Bool) {
        usernameField.setEditable(editable)
        hiddenPasswordField.setEditable(editable)
        visiblePasswordField.setEditable(editable)

        if editable || passwordManagerCoordinator.isEnabled {
            notNowButton.isHidden = passwordManagerCoordinator.isEnabled || credentials?.account.id != nil
            passwordManagerNotNowButton.isHidden = !passwordManagerCoordinator.isEnabled || credentials?.account.id != nil
            saveButton.isHidden = credentials?.account.id != nil || passwordManagerCoordinator.isLocked
            updateButton.isHidden = credentials?.account.id == nil || passwordManagerCoordinator.isLocked
            dontUpdateButton.isHidden = credentials?.account.id == nil
            openPasswordManagerButton.isHidden = !passwordManagerCoordinator.isLocked

            editButton.isHidden = true
            doneButton.isHidden = true

            titleLabel.isHidden = passwordManagerCoordinator.isEnabled
            passwordManagerTitle.isHidden = !passwordManagerCoordinator.isEnabled || passwordManagerCoordinator.isLocked
            passwordManagerAccountLabel.stringValue = "Connected to \(passwordManagerCoordinator.activeVaultEmail ?? "")"
            unlockPasswordManagerTitle.isHidden = !passwordManagerCoordinator.isEnabled || !passwordManagerCoordinator.isLocked
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
            if passwordManagerCoordinator.isEnabled {
                guard !passwordManagerCoordinator.isLocked else {
                    os_log("Failed to store credentials: Password manager is locked")
                    return
                }

                passwordManagerCoordinator.storeWebsiteCredentials(credentials) { error in
                    if let error = error {
                        os_log("Failed to store credentials: %s", type: .error, error.localizedDescription)
                    }
                }
            } else {
                _ = try AutofillSecureVaultFactory.makeVault(errorReporter: SecureVaultErrorReporter.shared).storeWebsiteCredentials(credentials)
                NSApp.delegateTyped.syncService?.scheduler.notifyDataChanged()
                os_log(.debug, log: OSLog.sync, "Requesting sync if enabled")
            }
        } catch {
            os_log("%s:%s: failed to store credentials %s", type: .error, className, #function, error.localizedDescription)
            Pixel.fire(.debug(event: .secureVaultError, error: error))
        }

        Pixel.fire(.autofillItemSaved(kind: .password))

        if passwordManagerCoordinator.isEnabled {
            passwordManagerCoordinator.reportPasswordSave()
        }

        if let domain = account.domain {
            if self.fireproofCheck.state == .on {
                FireproofDomains.shared.add(domain: domain)
            } else {
                // If the Fireproof checkbox has been unchecked, and the domain is Fireproof, then un-Fireproof it.
                guard FireproofDomains.shared.isFireproof(fireproofDomain: domain) else { return }
                FireproofDomains.shared.remove(domain: domain)
            }
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
                FireproofDomains.shared.add(domain: host)
            }
            notifyDelegate()
        }

    }

    @IBAction func onOpenPasswordManagerClicked(sender: Any?) {
        passwordManagerCoordinator.openPasswordManager()
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

    func loadFaviconForDomain(_ domain: String?) {
        guard let domain else {
            faviconImage.image = NSImage(named: NSImage.Name("Web"))
            return
        }
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

    private func subscribeToPasswordManagerState() {
        passwordManagerStateCancellable = passwordManagerCoordinator.bitwardenManagement.statusPublisher
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateViewState(editable: true)
            }
    }

}
