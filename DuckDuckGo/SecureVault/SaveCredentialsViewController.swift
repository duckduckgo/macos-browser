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
    @IBOutlet var saveButton: NSButton!
    @IBOutlet var fireproofCheck: NSButton!

    weak var delegate: SaveCredentialsDelegate?

    private var credentials: SecureVaultModels.WebsiteCredentials?

    private var saveButtonAction: (() -> Void)?

    var passwordData: Data {
        let string = hiddenPasswordField.isHidden ? visiblePasswordField.stringValue : hiddenPasswordField.stringValue
        return string.data(using: .utf8)!
    }

    func saveCredentials(_ credentials: SecureVaultModels.WebsiteCredentials) {
        self.credentials = credentials
        populateUIFromCredentials(credentials)

        self.saveButtonAction = { [weak self] in
            self?.performSave()
        }
    }

    func updateCredentials(_ credentials: SecureVaultModels.WebsiteCredentials) {
        self.credentials = credentials
        populateUIFromCredentials(credentials)

        self.saveButtonAction = { [weak self] in
            self?.performUpdate()
        }
    }

    @IBAction func onSaveClicked(sender: Any?) {
        saveButtonAction?()
    }

    @IBAction func onNotNowClicked(sender: Any?) {
        delegate?.shouldCloseSaveCredentialsViewController(self)

        let host = domainLabel.stringValue

        guard let window = view.window, !FireproofDomains.shared.isAllowed(fireproofDomain: host) else {
            os_log("%s: Window is nil", type: .error, className)
            return
        }

        let alert = NSAlert.fireproofAlert(with: host.dropWWW())
        alert.beginSheetModal(for: window) { response in
            if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                Pixel.fire(.fireproof(kind: .pwm, suggested: .suggested))
                FireproofDomains.shared.addToAllowed(domain: host)
            }
        }

        Pixel.fire(.fireproofSuggested())
    }

    /// Assuming per website basis.
    @IBAction func onNeverClicked(sender: Any?) {
        PasswordManagerSettings().doNotPromptOnDomain(domainLabel.stringValue)
        delegate?.shouldCloseSaveCredentialsViewController(self)
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
        saveButton.becomeFirstResponder()
    }

    func loadFaviconForDomain(_ domain: String) {
        faviconImage.image = LocalFaviconService.shared.getCachedFavicon(for: domain, mustBeFromUserScript: false)
            ?? NSImage(named: NSImage.Name("Web"))
    }

    func performSave() {
        let account = SecureVaultModels.WebsiteAccount(username: usernameField.stringValue.trimmingWhitespaces(),
                                                       domain: domainLabel.stringValue)
        let credentials = SecureVaultModels.WebsiteCredentials(account: account, password: passwordData)

        var cancellable: AnyCancellable?
        cancellable = SecureVaultFactory.default.makeVault().flatMap { vault in
            vault.storeWebsiteCredentials(credentials)
        }
        .sink { [weak self] _ in
            // Later, check for errors
            self?.delegate?.shouldCloseSaveCredentialsViewController(self!)
            cancellable?.cancel()
        } receiveValue: { [weak self] _ in
            DispatchQueue.main.async {
                if self?.fireproofCheck.state == .on {
                    Pixel.fire(.fireproof(kind: .pwm, suggested: .pwm))
                    FireproofDomains.shared.addToAllowed(domain: account.domain)
                }
            }
            cancellable?.cancel()
        }
    }

    func performUpdate() {
        let account = SecureVaultModels.WebsiteAccount(username: usernameField.stringValue.trimmingWhitespaces(),
                                                       domain: domainLabel.stringValue)
        let credentials = SecureVaultModels.WebsiteCredentials(account: account, password: passwordData)

        var cancellable: AnyCancellable?
        cancellable = SecureVaultFactory.default.makeVault().flatMap { vault in
            vault.storeWebsiteCredentials(credentials)
        }
        .sink { [weak self] _ in
            // Later, check for errors
            self?.delegate?.shouldCloseSaveCredentialsViewController(self!)
            cancellable?.cancel()
        } receiveValue: { _ in
            cancellable?.cancel()
        }
    }

    func populateUIFromCredentials(_ credentials: SecureVaultModels.WebsiteCredentials) {
        self.domainLabel.stringValue = credentials.account.domain
        self.usernameField.stringValue = credentials.account.username
        self.hiddenPasswordField.stringValue = String(data: credentials.password, encoding: .utf8) ?? ""
        self.visiblePasswordField.stringValue = self.hiddenPasswordField.stringValue
        self.loadFaviconForDomain(credentials.account.domain)
    }
}
