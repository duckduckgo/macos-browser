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
        
        guard let identity = identity else {
            assertionFailure("Tried to save identity, but the view controller didn't have one")
            return
        }
        
        do {
            try SecureVaultFactory.default.makeVault(errorReporter: SecureVaultErrorReporter.shared).storeIdentity(identity)
        } catch {
            os_log("%s:%: failed to store identity %s", type: .error, className, #function, error.localizedDescription)
        }
    }
    
    @IBAction func onOpenPreferencesClicked(sender: NSButton) {
        WindowControllersManager.shared.showPreferencesTab()
    }
    
    // MARK: - Public
    
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

        identityStackView.addArrangedSubview(label(titled: identity.formattedName))
        
        identityStackView.setCustomSpacingAfterLastView(20)
        
        identityStackView.addArrangedSubview(label(titled: identity.addressStreet))
        identityStackView.addArrangedSubview(label(titled: identity.addressStreet2))
        identityStackView.addArrangedSubview(label(titled: identity.addressCity))
        identityStackView.addArrangedSubview(label(titled: identity.addressProvince))
        identityStackView.addArrangedSubview(label(titled: identity.addressPostalCode))
        identityStackView.addArrangedSubview(label(titled: identity.addressCountryCode))
        
        identityStackView.setCustomSpacingAfterLastView(20)
        
        identityStackView.addArrangedSubview(label(titled: identity.homePhone))
        identityStackView.addArrangedSubview(label(titled: identity.mobilePhone))
        
        identityStackView.setCustomSpacingAfterLastView(20)
        
        identityStackView.addArrangedSubview(label(titled: identity.emailAddress))

    }
    
    private func label(titled title: String?) -> NSTextField? {
        guard let title = title else {
            return nil
        }

        let label = NSTextField(string: title)
        label.isEditable = false
        label.isBordered = false
        label.isSelectable = false
        label.isBezeled = false
        label.backgroundColor = .clear
        
        return label
    }

}
