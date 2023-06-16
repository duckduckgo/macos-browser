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
import DependencyInjection

protocol SaveIdentityDelegate: AnyObject {

    func shouldCloseSaveIdentityViewController(_: SaveIdentityViewController)

}

#if swift(>=5.9)
@Injectable
#endif
@MainActor
final class SaveIdentityViewController: NSViewController, Injectable {
    let dependencies: DependencyStorage

    @Injected
    var windowManager: WindowManagerProtocol

    enum Constants {
        static let storyboardName = "PasswordManager"
        static let identifier = "SaveIdentity"
    }

    static func create(dependencyProvider: DependencyProvider) -> SaveIdentityViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)
        let controller = storyboard.instantiateController(identifier: Constants.identifier) { coder in
            SaveIdentityViewController.init(coder: coder, dependencyProvider: dependencyProvider)
        }
        controller.loadView()

        return controller
    }

    @IBOutlet private var identityStackView: NSStackView!

    weak var delegate: SaveIdentityDelegate?

    private var identity: SecureVaultModels.Identity?
    private var appearanceCancellable: AnyCancellable?

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
            try SecureVaultFactory.default.makeVault(errorReporter: SecureVaultErrorReporter.shared).storeIdentity(identity)
            Pixel.fire(.autofillItemSaved(kind: .identity))
        } catch {
            os_log("%s:%s: failed to store identity %s", type: .error, className, #function, error.localizedDescription)
        }
    }

    @IBAction func onOpenPreferencesClicked(sender: NSButton) {
        windowManager.showPreferencesTab()
        self.delegate?.shouldCloseSaveIdentityViewController(self)
    }

    // MARK: - Public

    func saveIdentity(_ identity: SecureVaultModels.Identity) {
        self.identity = identity

        buildStackView(from: identity)
    }

    // MARK: -

    init?(coder: NSCoder, dependencyProvider: DependencyProvider) {
        self.dependencies = .init(dependencyProvider)

        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        appearanceCancellable = view.subscribeForAppApperanceUpdates()
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

}
