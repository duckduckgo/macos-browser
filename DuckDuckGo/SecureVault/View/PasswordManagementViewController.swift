//
//  PasswordManagementViewController.swift
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

import Foundation
import Combine
import SwiftUI
import BrowserServicesKit

protocol PasswordManagementDelegate: AnyObject {

    /// May not be called on main thread.
    func shouldClosePasswordManagementViewController(_: PasswordManagementViewController)

}

final class PasswordManagementViewController: NSViewController {

    static func create() -> Self {
        let storyboard = NSStoryboard(name: "PasswordManager", bundle: nil)
        // swiftlint:disable force_cast
        let controller = storyboard.instantiateController(withIdentifier: "PasswordManagement") as! Self
        controller.loadView()
        // swiftlint:enable force_cast
        return controller
    }

    weak var delegate: PasswordManagementDelegate?

    @IBOutlet var listContainer: NSView!
    @IBOutlet var itemContainer: NSView!
    @IBOutlet var searchField: NSTextField!

    @Published var domain: String?
    @Published var isDirty = false

    var listModel: PasswordManagementItemListModel?
    var itemModel: PasswordManagementItemModel?

    var secureVault: SecureVault? {
        try? SecureVaultFactory.default.makeVault()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        createListView()
        createItemView()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        if !isDirty {
            itemModel?.credentials = nil
        }

        refetchWithText(isDirty ? "" : domain ?? "")
    }

    private func refetchWithText(_ text: String) {
        fetchAccounts { [weak self] accounts in
            self?.listModel?.accounts = accounts
            self?.searchField.stringValue = text
            self?.updateFilter()

            if self?.isDirty == false {
                self?.listModel?.selectFirst()
            }
        }
    }

    private func syncModelsOnCredentials(_ credentials: SecureVaultModels.WebsiteCredentials) {
        self.itemModel?.credentials = credentials
        self.listModel?.updateAccount(credentials.account)
    }

    private func createItemView() {
        let itemModel = PasswordManagementItemModel(onDirtyChanged: { [weak self] isDirty in
            self?.isDirty = isDirty
            self?.postChange()
        }, onSaveRequested: { [weak self] in
            try? self?.secureVault?.storeWebsiteCredentials($0)
            self?.syncModelsOnCredentials($0)
            self?.postChange()
        }, onDeleteRequested: { [weak self] in
            self?.promptToDelete($0)
        })
        self.itemModel = itemModel

        let view = NSHostingView(rootView: PasswordManagementItemView().environmentObject(itemModel))
        view.frame = itemContainer.bounds
        itemContainer.addSubview(view)
        itemContainer.wantsLayer = true
    }

    func postChange() {
        NotificationCenter.default.post(name: .PasswordManagerChanged, object: isDirty)
    }

    func promptToDelete(_ credentials: SecureVaultModels.WebsiteCredentials) {
        guard let window = self.view.window,
              let id = credentials.account.id else { return }

        let alert = NSAlert.confirmDeleteLogin()
        alert.beginSheetModal(for: window) { response in

            switch response {
            case .alertFirstButtonReturn:
                try? self.secureVault?.deleteWebsiteCredentialsFor(accountId: id)
                self.itemModel?.credentials = nil
                self.refetchWithText(self.searchField.stringValue)
                self.postChange()

            case .alertSecondButtonReturn:
                break // cancel, do nothing

            default:
                fatalError("Unknown response \(response)")
            }

        }

    }

    private func createListView() {
        let listModel = PasswordManagementItemListModel(accounts: []) { [weak self] previousValue, newValue in
            guard let id = newValue.id,
                  let window = self?.view.window else { return }

            func loadCredentialsWithId(_ id: Int64) {
                guard let credentials = try? self?.secureVault?.websiteCredentialsFor(accountId: id) else { return }
                self?.syncModelsOnCredentials(credentials)
            }

            if self?.isDirty == true {
                let alert = NSAlert.saveChangesToLogin()
                alert.beginSheetModal(for: window) { response in

                    switch response {
                    case .alertFirstButtonReturn: // Save
                        self?.itemModel?.save()
                        loadCredentialsWithId(id)

                    case .alertSecondButtonReturn: // Discard
                        self?.itemModel?.cancel()
                        loadCredentialsWithId(id)

                    case .alertThirdButtonReturn: // Cancel
                        if let previousId = previousValue?.id {
                            self?.listModel?.selectAccountWithId(previousId)
                        }

                    default:
                        fatalError("Unknown response \(response)")
                    }

                }
            } else {
                loadCredentialsWithId(id)
            }
        }
        self.listModel = listModel

        let view = NSHostingView(rootView: PasswordManagementItemListView().environmentObject(listModel))
        view.frame = listContainer.bounds
        listContainer.addSubview(view)
    }

    private func updateFilter() {
        let text = searchField.stringValue.trimmingWhitespaces()
        listModel?.filterUsing(text: text)
    }

    private func fetchAccounts(completion: @escaping ([SecureVaultModels.WebsiteAccount]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let accounts = (try? self.secureVault?.accounts()) ?? []
            DispatchQueue.main.async {
                completion(accounts)
            }
        }
    }
    
}

extension PasswordManagementViewController: NSTextFieldDelegate {

    func controlTextDidChange(_ obj: Notification) {
        updateFilter()
    }

}
