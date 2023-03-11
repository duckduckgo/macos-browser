//
//  SavePaymentMethodViewController.swift
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

import Foundation
import BrowserServicesKit
import Combine
import os.log

protocol SavePaymentMethodDelegate: AnyObject {

    func shouldCloseSavePaymentMethodViewController(_: SavePaymentMethodViewController)

}

final class SavePaymentMethodViewController: NSViewController {

    enum Constants {
        static let storyboardName = "PasswordManager"
        static let identifier = "SavePaymentMethod"
    }

    static func create() -> SavePaymentMethodViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)
        let controller: SavePaymentMethodViewController = storyboard.instantiateController(identifier: Constants.identifier)
        controller.loadView()

        return controller
    }

    @IBOutlet var cardDetailsLabel: NSTextField!
    @IBOutlet var cardExpirationLabel: NSTextField!

    weak var delegate: SavePaymentMethodDelegate?

    private var paymentMethod: SecureVaultModels.CreditCard?
    private var appearanceCancellable: AnyCancellable?

    // MARK: - Public

    func savePaymentMethod(_ paymentMethod: SecureVaultModels.CreditCard) {
        self.paymentMethod = paymentMethod

        let type = CreditCardValidation.type(for: paymentMethod.cardNumber)
        cardDetailsLabel.stringValue = "\(type.displayName) ••••\(paymentMethod.cardSuffix)"

        if let expirationMonth = paymentMethod.expirationMonth, let expirationYear = paymentMethod.expirationYear {
            cardExpirationLabel.stringValue = "\(expirationMonth)/\(expirationYear)"
        } else {
            cardExpirationLabel.stringValue = ""
        }
    }

    // MARK: - Actions

    @IBAction func onNotNowClicked(sender: NSButton) {
        self.delegate?.shouldCloseSavePaymentMethodViewController(self)
    }

    @IBAction func onSaveClicked(sender: NSButton) {
        defer {
            self.delegate?.shouldCloseSavePaymentMethodViewController(self)
        }

        guard var paymentMethod = paymentMethod else {
            assertionFailure("Tried to save payment method, but the view controller didn't have one")
            return
        }

        paymentMethod.title = CreditCardValidation.type(for: paymentMethod.cardNumber).displayName

        do {
            try SecureVaultFactory.default.makeVault(errorReporter: SecureVaultErrorReporter.shared).storeCreditCard(paymentMethod)
        } catch {
            os_log("%s:%s: failed to store payment method %s", type: .error, className, #function, error.localizedDescription)
        }
    }

    @IBAction func onOpenPreferencesClicked(sender: NSButton) {
        WindowControllersManager.shared.showPreferencesTab()
        self.delegate?.shouldCloseSavePaymentMethodViewController(self)
    }

    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        appearanceCancellable = view.subscribeForAppApperanceUpdates()
    }

}
