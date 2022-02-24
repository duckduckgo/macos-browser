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

// swiftlint:disable file_length

protocol PasswordManagementDelegate: AnyObject {

    /// May not be called on main thread.
    func shouldClosePasswordManagementViewController(_: PasswordManagementViewController)

}

// swiftlint:disable type_body_length
final class PasswordManagementViewController: NSViewController {

    static func create() -> Self {
        let storyboard = NSStoryboard(name: "PasswordManager", bundle: nil)
        // swiftlint:disable force_cast
        let controller: Self = storyboard.instantiateController(withIdentifier: "PasswordManagement") as! Self
        controller.loadView()
        // swiftlint:enable force_cast
        return controller
    }

    weak var delegate: PasswordManagementDelegate?

    @IBOutlet var listContainer: NSView!
    @IBOutlet var itemContainer: NSView!
    @IBOutlet var searchField: NSTextField!
    @IBOutlet var divider: NSView!
    @IBOutlet var emptyState: NSView!
    @IBOutlet var emptyStateTitle: NSTextField!
    @IBOutlet var emptyStateMessage: NSTextField!

    var editingCancellable: AnyCancellable?

    var domain: String?
    var isDirty = false

    var listModel: PasswordManagementItemListModel?
    var listView: NSView?

    var itemModel: PasswordManagementItemModel? {
        didSet {
            editingCancellable?.cancel()
            editingCancellable = nil

            editingCancellable = itemModel?.isEditingPublisher.sink(receiveValue: { [weak self] isEditing in
                self?.divider.isHidden = isEditing
            })
        }
    }

    var secureVault: SecureVault? {
        try? SecureVaultFactory.default.makeVault(errorReporter: SecureVaultErrorReporter.shared)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        createListView()
        createLoginItemView()

        emptyStateTitle.attributedStringValue = NSAttributedString.make(emptyStateTitle.stringValue, lineHeight: 1.14, kern: -0.23)
        emptyStateMessage.attributedStringValue = NSAttributedString.make(emptyStateMessage.stringValue, lineHeight: 1.05, kern: -0.08)
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        if !isDirty {
            itemModel?.clearSecureVaultModel()
        }

        // Only select the matching item directly if macOS 11 is available, as 10.15 doesn't support scrolling directly to a given
        // item in SwiftUI. On 10.15, show the matching item by filtering the search bar automatically instead.
        if #available(macOS 11.0, *) {
            refetchWithText("", selectItemMatchingDomain: domain?.dropWWW(), clearWhenNoMatches: true)
        } else {
            refetchWithText(isDirty ? "" : domain ?? "", clearWhenNoMatches: true)
        }
    }

    @IBAction func onNewClicked(_ sender: NSButton) {
        let menu = createNewSecureVaultItemMenu()
        let location = NSPoint(x: sender.frame.origin.x, y: sender.frame.origin.y - (sender.frame.height / 2) + 6)

        menu.popUp(positioning: nil, at: location, in: sender.superview)
    }

    @IBAction func onImportClicked(_ sender: NSButton) {
        DataImportViewController.show()
    }

    private func refetchWithText(_ text: String,
                                 selectItemMatchingDomain: String? = nil,
                                 clearWhenNoMatches: Bool = false,
                                 completion: (() -> Void)? = nil) {
        fetchSecureVaultItems { [weak self] items in
            self?.listModel?.update(items: items)
            self?.searchField.stringValue = text
            self?.updateFilter()

            if clearWhenNoMatches && self?.listModel?.displayedItems.isEmpty == true {
                self?.searchField.stringValue = ""
                self?.updateFilter()                
            } else if self?.isDirty == false {
                if let selectItemMatchingDomain = selectItemMatchingDomain {
                    self?.listModel?.selectLoginWithDomainOrFirst(domain: selectItemMatchingDomain)
                } else {
                    self?.listModel?.selectFirst()
                }
            }

            completion?()
        }
    }

    func postChange() {
        NotificationCenter.default.post(name: .PasswordManagerChanged, object: isDirty)
    }

    func clear() {
        self.listModel?.update(items: [])
        self.listModel?.filter = ""
        self.listModel?.clearSelection()
        self.itemModel?.clearSecureVaultModel()
    }

    private func syncModelsOnCredentials(_ credentials: SecureVaultModels.WebsiteCredentials, select: Bool = false) {
        self.itemModel?.setSecureVaultModel(credentials)
        self.listModel?.update(item: SecureVaultItem.account(credentials.account))

        if select {
            self.listModel?.selected(item: SecureVaultItem.account(credentials.account))
        }
    }

    private func syncModelsOnAccount(_ account: SecureVaultItem, select: Bool = false) {
        self.itemModel?.setSecureVaultModel(account)
        self.listModel?.update(item: account)

        if select {
            self.listModel?.selected(item: account)
        }
    }

    private func syncModelsOnIdentity(_ identity: SecureVaultModels.Identity, select: Bool = false) {
        self.itemModel?.setSecureVaultModel(identity)
        self.listModel?.update(item: SecureVaultItem.identity(identity))

        if select {
            self.listModel?.selected(item: SecureVaultItem.identity(identity))
        }
    }

    private func syncModelsOnCreditCard(_ card: SecureVaultModels.CreditCard, select: Bool = false) {
        self.itemModel?.setSecureVaultModel(card)
        self.listModel?.update(item: SecureVaultItem.card(card))

        if select {
            self.listModel?.selected(item: SecureVaultItem.card(card))
        }
    }

    private func createLoginItemView() {
        let itemModel = PasswordManagementLoginModel(onDirtyChanged: { [weak self] isDirty in
            self?.isDirty = isDirty
            self?.postChange()
        }, onSaveRequested: { [weak self] credentials in
            self?.doSaveCredentials(credentials)
        }, onDeleteRequested: { [weak self] credentials in
            self?.promptToDelete(credentials: credentials)
        }) { [weak self] in
            self?.refetchWithText(self!.searchField.stringValue)
        }

        self.itemModel = itemModel

        let view = NSHostingView(rootView: PasswordManagementLoginItemView().environmentObject(itemModel))
        replaceItemContainerChildView(with: view)
    }

    private func createIdentityItemView() {
        let itemModel = PasswordManagementIdentityModel(onDirtyChanged: { [weak self] isDirty in
            self?.isDirty = isDirty
            self?.postChange()
        }, onSaveRequested: { [weak self] note in
            self?.doSaveIdentity(note)
        }, onDeleteRequested: { [weak self] identity in
            self?.promptToDelete(identity: identity)
        }) { [weak self] in
            self?.refetchWithText(self!.searchField.stringValue)
        }

        self.itemModel = itemModel

        let view = NSHostingView(rootView: PasswordManagementIdentityItemView().environmentObject(itemModel))
        replaceItemContainerChildView(with: view)
    }

    private func createCreditCardItemView() {
        let itemModel = PasswordManagementCreditCardModel(onDirtyChanged: { [weak self] isDirty in
            self?.isDirty = isDirty
            self?.postChange()
        }, onSaveRequested: { [weak self] card in
            self?.doSaveCreditCard(card)
        }, onDeleteRequested: { [weak self] card in
            self?.promptToDelete(card: card)
        }) { [weak self] in
            self?.refetchWithText(self!.searchField.stringValue)
        }

        self.itemModel = itemModel

        let view = NSHostingView(rootView: PasswordManagementCreditCardItemView().environmentObject(itemModel))
        replaceItemContainerChildView(with: view)
    }

    private func clearSelectedItem() {
        itemContainer.subviews.forEach {
            $0.removeFromSuperview()
        }
    }

    private func replaceItemContainerChildView(with view: NSView) {
        emptyState.isHidden = true
        clearSelectedItem()

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

    private func doSaveIdentity(_ identity: SecureVaultModels.Identity) {
        let isNew = identity.id == nil

        do {
            guard let storedIdentityID = try secureVault?.storeIdentity(identity),
                  let storedIdentity = try secureVault?.identityFor(id: storedIdentityID) else { return }

            itemModel?.cancel()
            if isNew {
                refetchWithText(searchField.stringValue) { [weak self] in
                    self?.syncModelsOnIdentity(storedIdentity, select: true)
                }
            } else {
                syncModelsOnIdentity(storedIdentity)
            }
            postChange()

        } catch {
            // Which errors can occur when saving identities?
        }
    }

    private func doSaveCreditCard(_ card: SecureVaultModels.CreditCard) {
        let isNew = card.id == nil

        do {
            guard let storedCardID = try secureVault?.storeCreditCard(card),
                  let storedCard = try secureVault?.creditCardFor(id: storedCardID) else { return }

            itemModel?.cancel()
            if isNew {
                refetchWithText(searchField.stringValue) { [weak self] in
                    self?.syncModelsOnCreditCard(storedCard, select: true)
                }
            } else {
                syncModelsOnCreditCard(storedCard)
            }
            postChange()

        } catch {
            // Which errors can occur when saving cards?
        }
    }

    private func promptToDelete(credentials: SecureVaultModels.WebsiteCredentials) {
        guard let window = self.view.window,
              let id = credentials.account.id else { return }

        let alert = NSAlert.passwordManagerConfirmDeleteLogin()
        alert.beginSheetModal(for: window) { response in

            switch response {
            case .alertFirstButtonReturn:
                try? self.secureVault?.deleteWebsiteCredentialsFor(accountId: id)
                self.itemModel?.clearSecureVaultModel()
                self.refetchWithText(self.searchField.stringValue)
                self.postChange()

            default:
                break // cancel, do nothing
            }

        }
    }

    private func promptToDelete(identity: SecureVaultModels.Identity) {
        guard let window = self.view.window,
              let id = identity.id else { return }

        let alert = NSAlert.passwordManagerConfirmDeleteIdentity()
        alert.beginSheetModal(for: window) { response in

            switch response {
            case .alertFirstButtonReturn:
                try? self.secureVault?.deleteIdentityFor(identityId: id)
                self.itemModel?.clearSecureVaultModel()
                self.refetchWithText(self.searchField.stringValue)
                self.postChange()

            default:
                break // cancel, do nothing
            }

        }
    }

    private func promptToDelete(card: SecureVaultModels.CreditCard) {
        guard let window = self.view.window,
              let id = card.id else { return }

        let alert = NSAlert.passwordManagerConfirmDeleteCard()
        alert.beginSheetModal(for: window) { response in

            switch response {
            case .alertFirstButtonReturn:
                try? self.secureVault?.deleteCreditCardFor(cardId: id)
                self.itemModel?.clearSecureVaultModel()
                self.refetchWithText(self.searchField.stringValue)
                self.postChange()

            default:
                break // cancel, do nothing
            }

        }
    }

    // swiftlint:disable function_body_length
    private func createListView() {
        let listModel = PasswordManagementItemListModel { [weak self] previousValue, newValue in
            guard let newValue = newValue,
                  let id = newValue.secureVaultID,
                  let window = self?.view.window else {
                      self?.itemModel = nil
                      self?.clearSelectedItem()

                      return
                  }

            func loadNewItemWithID() {
                switch newValue {
                case .account:
                    self?.createLoginItemView()
                    if let credentials = try? self?.secureVault?.websiteCredentialsFor(accountId: id) {
                        self?.syncModelsOnCredentials(credentials)
                    } else {
                        self?.syncModelsOnAccount(newValue)
                    }
                case .card:
                    guard let card = try? self?.secureVault?.creditCardFor(id: id) else { return }
                    self?.createCreditCardItemView()
                    self?.syncModelsOnCreditCard(card)
                case .identity:
                    guard let identity = try? self?.secureVault?.identityFor(id: id) else { return }
                    self?.createIdentityItemView()
                    self?.syncModelsOnIdentity(identity)
                }
            }

            if self?.isDirty == true {
                let alert = NSAlert.passwordManagerSaveChangesToLogin()
                alert.beginSheetModal(for: window) { response in

                    switch response {
                    case .alertFirstButtonReturn: // Save
                        self?.itemModel?.save()
                        loadNewItemWithID()

                    case .alertSecondButtonReturn: // Discard
                        self?.itemModel?.cancel()
                        loadNewItemWithID()

                    default: // Cancel
                        if let previousValue = previousValue {
                            self?.listModel?.select(item: previousValue, notify: false)
                        }
                    }

                }
            } else {
                loadNewItemWithID()
            }
        }

        self.listModel = listModel
        self.listView = NSHostingView(rootView: PasswordManagementItemListView().environmentObject(listModel))
    }
    // swiftlint:enable function_body_length
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        if let listView = self.listView {
            listView.frame = listContainer.bounds
            listContainer.addSubview(listView)
        }
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        listView?.removeFromSuperview()
    }

    private func createNewSecureVaultItemMenu() -> NSMenu {
        let menu = NSMenu()

        menu.items = [
            NSMenuItem(title: UserText.pmNewCard, action: #selector(createNewCreditCard), keyEquivalent: ""),
            NSMenuItem(title: UserText.pmNewLogin, action: #selector(createNewLogin), keyEquivalent: ""),
            NSMenuItem(title: UserText.pmNewIdentity, action: #selector(createNewIdentity), keyEquivalent: ""),
        ]

        return menu
    }

    private func updateFilter() {
        let text = searchField.stringValue.trimmingWhitespaces()
        listModel?.filter = text
    }

    private func fetchSecureVaultItems(completion: @escaping ([SecureVaultItem]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let accounts = (try? self.secureVault?.accounts()) ?? []
            let cards = (try? self.secureVault?.creditCards()) ?? []
            let identities = (try? self.secureVault?.identities()) ?? []

            let items = accounts.map(SecureVaultItem.account) +
                        cards.map(SecureVaultItem.card) +
                        identities.map(SecureVaultItem.identity)

            DispatchQueue.main.async {
                self.emptyState.isHidden = !items.isEmpty
                completion(items)
            }
        }
    }

    @objc
    private func createNewCreditCard() {
        guard let window = view.window else { return }

        func createNew() {
            createCreditCardItemView()

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

                default: // Cancel
                    break // just do nothing
                }

            }
        } else {
            createNew()
        }
    }

    @objc
    private func createNewLogin() {
        guard let window = view.window else { return }

        func createNew() {
            createLoginItemView()

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

                default: // Cancel
                    break // just do nothing
                }

            }
        } else {
            createNew()
        }
    }

    @objc
    private func createNewIdentity() {
        guard let window = view.window else { return }

        func createNew() {
            createIdentityItemView()

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

                default: // Cancel
                    break // just do nothing
                }

            }
        } else {
            createNew()
        }
    }

}

extension PasswordManagementViewController: NSTextFieldDelegate {

    func controlTextDidChange(_ obj: Notification) {
        updateFilter()
    }

}

// swiftlint:enable file_length
