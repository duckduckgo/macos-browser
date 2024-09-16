//
//  SaveIdentityViewController.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import PixelKit
import os.log

protocol SaveIdentityDelegate: AnyObject {

    func shouldCloseSaveIdentityViewController(_: SaveIdentityViewController)

}

final class SaveIdentityViewController: NSViewController {

    enum Constants {
        static let storyboardName = "PasswordManager"
        static let identifier = "SaveIdentity"
    }

    static func create() -> SaveIdentityViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)
        let controller: SaveIdentityViewController = storyboard.instantiateController(identifier: Constants.identifier)
        controller.loadView()

        return controller
    }

    @IBOutlet private var identityStackView: NSStackView!
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var notNowButton: NSButton!
    @IBOutlet weak var saveButton: NSButton!

    weak var delegate: SaveIdentityDelegate?

    private var identity: SecureVaultModels.Identity?

    // MARK: - Actions

    @IBAction func onNotNowClicked(sender: NSButton) {
        self.delegate?.shouldCloseSaveIdentityViewController(self)
    }

    @IBAction func onSaveClicked(sender: NSButton) {
        defer {
            self.delegate?.shouldCloseSaveIdentityViewController(self)
        }

        guard var identity = identity else {
            assertionFailure("Tried to save identity, but the view controller didn't have one")
            return
        }

        identity.title = UserText.pmDefaultIdentityAutofillTitle

        do {
            try AutofillSecureVaultFactory.makeVault(reporter: SecureVaultReporter.shared).storeIdentity(identity)
            PixelKit.fire(GeneralPixel.autofillItemSaved(kind: .identity))
        } catch {
            Logger.general.error("Failed to store identity \(error.localizedDescription)")
            PixelKit.fire(DebugEvent(GeneralPixel.secureVaultError(error: error)))
        }
    }

    @IBAction func onOpenPreferencesClicked(sender: NSButton) {
        WindowControllersManager.shared.showPreferencesTab()
        self.delegate?.shouldCloseSaveIdentityViewController(self)
    }

    // MARK: - Public

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpStrings()
    }

    func saveIdentity(_ identity: SecureVaultModels.Identity) {
        self.identity = identity

        buildStackView(from: identity)
    }

    // MARK: - Private

    private func buildStackView(from identity: SecureVaultModels.Identity) {

        // Placeholder views are used in the Storyboard, which need to be removed before laying out the correct views.
        identityStackView.arrangedSubviews.forEach { view in
            view.removeFromSuperview()
        }

        identityStackView.addArrangedSubview(NSTextField.optionalLabel(titled: identity.longFormattedName))

        identityStackView.setCustomSpacingAfterLastView(20)

        identityStackView.addArrangedSubview(NSTextField.optionalLabel(titled: identity.addressStreet))
        identityStackView.addArrangedSubview(NSTextField.optionalLabel(titled: identity.addressStreet2))
        identityStackView.addArrangedSubview(NSTextField.optionalLabel(titled: identity.addressCity))
        identityStackView.addArrangedSubview(NSTextField.optionalLabel(titled: identity.addressProvince))
        identityStackView.addArrangedSubview(NSTextField.optionalLabel(titled: identity.addressPostalCode))
        identityStackView.addArrangedSubview(NSTextField.optionalLabel(titled: identity.addressCountryCode))

        identityStackView.setCustomSpacingAfterLastView(20)

        identityStackView.addArrangedSubview(NSTextField.optionalLabel(titled: identity.homePhone))
        identityStackView.addArrangedSubview(NSTextField.optionalLabel(titled: identity.mobilePhone))

        identityStackView.setCustomSpacingAfterLastView(20)

        identityStackView.addArrangedSubview(NSTextField.optionalLabel(titled: identity.emailAddress))

    }

    private func setUpStrings() {
        titleLabel.stringValue = UserText.passwordManagementSaveAddress
        notNowButton.title = UserText.notNow
        saveButton.title = UserText.save
    }

}
