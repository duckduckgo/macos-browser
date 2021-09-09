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
    @IBOutlet var divider: NSView!

    var editingCancellable: AnyCancellable?

    var domain: String?
    var isDirty = false

    var listModel: PasswordManagementItemListModel?
    var itemModel: PasswordManagementItemModel?

    var secureVault: SecureVault? {
        try? SecureVaultFactory.default.makeVault()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        createListView()
        createItemView()
        subscribeToEditingState()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        if !isDirty {
            itemModel?.credentials = nil
        }

        refetchWithText(isDirty ? "" : domain ?? "", clearWhenNoMatches: true)
    }

    @IBAction func onNewClicked(_ sender: Any?) {

        guard let window = view.window else { return }

        func createNew() {
            listModel?.clearSelection()
            itemModel?.createNew()
        }

        if isDirty {
            let alert = NSAlert.passwordManagerSaveChangesToLogin()
            alert.beginSheetModal(for: window) { response in

                switch response {
                case .alertFirstButtonReturn: // Save
                    self.itemModel?.save()
                    createNew()

                case .alertSecondButtonReturn: // Discard
                    self.itemModel?.cancel()
                    createNew()

                case .alertThirdButtonReturn: // Cancel
                    break // just do nothing

                default:
                    fatalError("Unknown response \(response)")
                }

            }
        } else {
            createNew()
        }
    }

    private func subscribeToEditingState() {
        editingCancellable = itemModel?.$isEditing.sink(receiveValue: { [weak self] isEditing in
            self?.divider.isHidden = isEditing
        })
    }

    private func refetchWithText(_ text: String, clearWhenNoMatches: Bool = false, completion: (() -> Void)? = nil) {
        fetchAccounts { [weak self] accounts in
            self?.listModel?.accounts = accounts
            self?.searchField.stringValue = text
            self?.updateFilter()

            if clearWhenNoMatches && self?.listModel?.displayedAccounts.isEmpty == true {
                self?.searchField.stringValue = ""
                self?.updateFilter()
            } else if self?.isDirty == false {
                self?.listModel?.selectFirst()
            }

            completion?()
        }
    }

    func postChange() {
        NotificationCenter.default.post(name: .PasswordManagerChanged, object: isDirty)
    }

    func clear() {
        self.listModel?.accounts = []
        self.listModel?.filter = ""
        self.listModel?.clearSelection()
        self.itemModel?.credentials = nil
    }

    private func syncModelsOnCredentials(_ credentials: SecureVaultModels.WebsiteCredentials, select: Bool = false) {
        self.itemModel?.credentials = credentials
        self.listModel?.updateAccount(credentials.account)

        if select {
            self.listModel?.selectAccount(credentials.account)
        }
    }

    private func createItemView() {
        let itemModel = PasswordManagementItemModel(onDirtyChanged: { [weak self] isDirty in
            self?.isDirty = isDirty
            self?.postChange()
        }, onSaveRequested: { [weak self] credentials in
            self?.doSaveCredentials(credentials)
        }, onDeleteRequested: { [weak self] in
            self?.promptToDelete($0)
        })
        self.itemModel = itemModel

        let view = NSHostingView(rootView: PasswordManagementItemView().environmentObject(itemModel))
        view.frame = itemContainer.bounds
        view.wantsLayer = true
        view.layer?.masksToBounds = false
        itemContainer.addSubview(view)
        itemContainer.wantsLayer = true
        itemContainer.layer?.masksToBounds = false
    }

    private func doSaveCredentials(_ credentials: SecureVaultModels.WebsiteCredentials) {
        let isNew = credentials.account.id == nil

        do {
            guard let id = try secureVault?.storeWebsiteCredentials(credentials),
                  let savedCredentials = try secureVault?.websiteCredentialsFor(accountId: id) else {
                return
            }

            itemModel?.cancel()
            if isNew {
                refetchWithText(searchField.stringValue) { [weak self] in
                    self?.syncModelsOnCredentials(savedCredentials, select: true)
                }
            } else {
                syncModelsOnCredentials(savedCredentials)
            }
            postChange()

        } catch {
            if let window = view.window, case SecureVaultError.duplicateRecord = error {
                NSAlert.passwordManagerDuplicateLogin().beginSheetModal(for: window)
            }
        }
    }

    private func promptToDelete(_ credentials: SecureVaultModels.WebsiteCredentials) {
        guard let window = self.view.window,
              let id = credentials.account.id else { return }

        let alert = NSAlert.passwordManagerConfirmDeleteLogin()
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
        let listModel = PasswordManagementItemListModel { [weak self] previousValue, newValue in
            guard let id = newValue.id,
                  let window = self?.view.window else { return }

            func loadCredentialsWithId() {
                guard let credentials = try? self?.secureVault?.websiteCredentialsFor(accountId: id) else { return }
                self?.syncModelsOnCredentials(credentials)
            }

            if self?.isDirty == true {
                let alert = NSAlert.passwordManagerSaveChangesToLogin()
                alert.beginSheetModal(for: window) { response in

                    switch response {
                    case .alertFirstButtonReturn: // Save
                        self?.itemModel?.save()
                        loadCredentialsWithId()

                    case .alertSecondButtonReturn: // Discard
                        self?.itemModel?.cancel()
                        loadCredentialsWithId()

                    case .alertThirdButtonReturn: // Cancel
                        if let previousId = previousValue?.id {
                            self?.listModel?.selectAccountWithId(previousId)
                        }

                    default:
                        fatalError("Unknown response \(response)")
                    }

                }
            } else {
                loadCredentialsWithId()
            }
        }
        self.listModel = listModel

        let view = NSHostingView(rootView: PasswordManagementItemListView().environmentObject(listModel))
        view.frame = listContainer.bounds
        listContainer.addSubview(view)
    }

    private func updateFilter() {
        let text = searchField.stringValue.trimmingWhitespaces()
        listModel?.filter = text
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
