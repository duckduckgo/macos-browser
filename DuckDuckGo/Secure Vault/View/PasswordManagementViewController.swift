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

// swiftlint:disable:next type_body_length
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
    @IBOutlet var addVaultItemButton: NSButton!
    @IBOutlet var moreButton: NSButton!
    @IBOutlet var searchField: NSTextField!
    @IBOutlet var divider: NSView!
    @IBOutlet var emptyState: NSView!
    @IBOutlet var emptyStateImageView: NSImageView!
    @IBOutlet var emptyStateTitle: NSTextField!
    @IBOutlet var emptyStateMessage: NSTextField!
    @IBOutlet var emptyStateButton: NSButton!

    @IBOutlet var lockScreen: NSView!
    @IBOutlet var lockScreenIconImageView: NSImageView! {
        didSet {
            if DeviceAuthenticator.deviceSupportsBiometrics {
                lockScreenIconImageView.image = NSImage(named: "LoginsLockTouchID")
            } else {
                lockScreenIconImageView.image = NSImage(named: "LoginsLockPassword")
            }
        }
    }

    @IBOutlet var lockScreenDurationLabel: NSTextField!
    @IBOutlet var lockScreenOpenInPreferencesTextView: NSTextView! {
        didSet {
            lockScreenOpenInPreferencesTextView.delegate = self

            let linkAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor(named: "LinkBlueColor")!,
                .cursor: NSCursor.pointingHand
            ]

            lockScreenOpenInPreferencesTextView.linkTextAttributes = linkAttributes

            let string = NSMutableAttributedString(string: UserText.pmLockScreenPreferencesLabel + " ")
            let linkString = NSMutableAttributedString(string: UserText.pmLockScreenPreferencesLink, attributes: [
                .link: URL.preferencePane(.autofill)
            ])

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            string.append(linkString)
            string.addAttributes([
                .cursor: NSCursor.arrow,
                .paragraphStyle: paragraphStyle,
                .font: NSFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor(named: "BlackWhite60")!
            ], range: NSRange(location: 0, length: string.length))

            lockScreenOpenInPreferencesTextView.textStorage?.setAttributedString(string)
        }
    }

    var emptyStateCancellable: AnyCancellable?
    var editingCancellable: AnyCancellable?
    var appearanceCancellable: AnyCancellable?

    var domain: String?
    var isEditing = false
    var isDirty = false {
        didSet {
            listModel?.canChangeCategory = !isDirty
        }
    }

    var listModel: PasswordManagementItemListModel? {
        didSet {
            emptyStateCancellable?.cancel()
            emptyStateCancellable = nil

            emptyStateCancellable = listModel?.$emptyState.dropFirst().sink(receiveValue: { [weak self] newEmptyState in
                self?.updateEmptyState(state: newEmptyState)
            })
        }
    }

    var listView: NSView?

    var itemModel: PasswordManagementItemModel? {
        didSet {
            editingCancellable?.cancel()
            editingCancellable = nil

            editingCancellable = itemModel?.isEditingPublisher.sink(receiveValue: { [weak self] isEditing in
                guard let self = self else { return }

                self.isEditing = isEditing
                self.divider.isHidden = isEditing
                self.updateEmptyState(state: self.listModel?.emptyState)

                self.searchField.isEditable = !isEditing
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

        appearanceCancellable = view.subscribeForAppApperanceUpdates()

        emptyStateTitle.attributedStringValue = NSAttributedString.make(emptyStateTitle.stringValue, lineHeight: 1.14, kern: -0.23)
        emptyStateMessage.attributedStringValue = NSAttributedString.make(emptyStateMessage.stringValue, lineHeight: 1.05, kern: -0.08)

        addVaultItemButton.sendAction(on: .leftMouseDown)
        moreButton.sendAction(on: .leftMouseDown)

        NotificationCenter.default.addObserver(forName: .deviceBecameLocked, object: nil, queue: .main) { [weak self] _ in
            self?.displayLockScreen()
        }

        NotificationCenter.default.addObserver(forName: .dataImportComplete, object: nil, queue: .main) { [weak self] _ in
            self?.refreshData()
        }
    }

    private func toggleLockScreen(hidden: Bool) {
        if hidden {
            hideLockScreen()
        } else {
            displayLockScreen()
        }
    }

    private func displayLockScreen() {
        lockScreen.isHidden = false
        searchField.isEnabled = false
        addVaultItemButton.isEnabled = false

        view.window?.makeFirstResponder(nil)
    }

    private func hideLockScreen() {
        lockScreen.isHidden = true
        searchField.isEnabled = true
        addVaultItemButton.isEnabled = true
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        lockScreenDurationLabel.stringValue = UserText.pmLockScreenDuration(duration: AutofillPreferences().autoLockThreshold.title)

        if let listView = self.listView {
            listView.frame = listContainer.bounds
            listContainer.addSubview(listView)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        if !isDirty {
            itemModel?.clearSecureVaultModel()
        }

        // Only select the matching item directly if macOS 11 is available, as 10.15 doesn't support scrolling directly to a given
        // item in SwiftUI. On 10.15, show the matching item by filtering the search bar automatically instead.
        if #available(macOS 11.0, *) {
            refetchWithText("", selectItemMatchingDomain: domain?.droppingWwwPrefix(), clearWhenNoMatches: true)
        } else {
            refetchWithText(isDirty ? "" : domain ?? "", clearWhenNoMatches: true)
        }

        promptForAuthenticationIfNecessary()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        listView?.removeFromSuperview()
    }

    private func promptForAuthenticationIfNecessary() {
        let authenticator = DeviceAuthenticator.shared

        toggleLockScreen(hidden: !authenticator.requiresAuthentication)

        authenticator.authenticateUser(reason: .unlockLogins) { authenticationResult in
            self.toggleLockScreen(hidden: authenticationResult.authenticated)
        }
    }

    @IBAction func onNewClicked(_ sender: NSButton) {
        let menu = createNewSecureVaultItemMenu()
        let location = NSPoint(x: sender.frame.origin.x, y: sender.frame.origin.y - (sender.frame.height / 2) + 6)

        menu.popUp(positioning: nil, at: location, in: sender.superview)
    }

    @IBAction func moreButtonAction(_ sender: NSButton) {
        let location = NSPoint(x: sender.frame.origin.x, y: sender.frame.origin.y - (sender.frame.height / 2) + 6)
        sender.menu?.popUp(positioning: nil, at: location, in: sender.superview)
    }

    @IBAction func openAutofillPreferences(_ sender: Any) {
        WindowControllersManager.shared.showPreferencesTab(withSelectedPane: .autofill)
        self.dismiss()
    }

    @IBAction func openImportBrowserDataWindow(_ sender: Any?) {
        self.dismiss()
        NSApp.sendAction(#selector(openImportBrowserDataWindow(_:)), to: nil, from: sender)
    }

    @IBAction func onImportClicked(_ sender: NSButton) {
        self.dismiss()
        DataImportViewController.show()
    }

    @IBAction func deviceAuthenticationRequested(_ sender: NSButton) {
        promptForAuthenticationIfNecessary()
    }

    @IBAction func toggleLock(_ sender: Any) {
        if DeviceAuthenticator.shared.requiresAuthentication {
            promptForAuthenticationIfNecessary()
        } else {
            DeviceAuthenticator.shared.lock()
        }
    }

    private func refetchWithText(_ text: String,
                                 selectItemMatchingDomain: String? = nil,
                                 clearWhenNoMatches: Bool = false,
                                 completion: (() -> Void)? = nil) {
        let category = SecureVaultSorting.Category.allItems
        fetchSecureVaultItems(category: category) { [weak self] items in
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
        self.listModel?.clear()
        self.itemModel?.clearSecureVaultModel()
    }

    func select(category: SecureVaultSorting.Category?) {
        guard let category = category else {
            return
        }

        if let descriptor = self.listModel?.sortDescriptor {
            self.listModel?.sortDescriptor = .init(category: category, parameter: descriptor.parameter, order: descriptor.order)
        } else {
            self.listModel?.sortDescriptor = .init(category: category, parameter: .title, order: .ascending)
        }
    }

    private func syncModelsOnCredentials(_ credentials: SecureVaultModels.WebsiteCredentials, select: Bool = false) {
        self.itemModel?.setSecureVaultModel(credentials)
        self.listModel?.update(item: SecureVaultItem.account(credentials.account))

        if select {
            self.listModel?.selected(item: SecureVaultItem.account(credentials.account))
        }
    }

    private func syncModelsOnIdentity(_ identity: SecureVaultModels.Identity, select: Bool = false) {
        self.itemModel?.setSecureVaultModel(identity)
        self.listModel?.update(item: SecureVaultItem.identity(identity))

        if select {
            self.listModel?.selected(item: SecureVaultItem.identity(identity))
        }
    }

    private func syncModelsOnNote(_ note: SecureVaultModels.Note, select: Bool = false) {
        self.itemModel?.setSecureVaultModel(note)
        self.listModel?.update(item: SecureVaultItem.note(note))

        if select {
            self.listModel?.selected(item: SecureVaultItem.note(note))
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
        })

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
        })

        self.itemModel = itemModel

        let view = NSHostingView(rootView: PasswordManagementIdentityItemView().environmentObject(itemModel))
        replaceItemContainerChildView(with: view)
    }

    private func createNoteItemView() {
        let itemModel = PasswordManagementNoteModel(onDirtyChanged: { [weak self] isDirty in
            self?.isDirty = isDirty
            self?.postChange()
        }, onSaveRequested: { [weak self] note in
            self?.doSaveNote(note)
        }, onDeleteRequested: { [weak self] note in
            self?.promptToDelete(note: note)
        })

        self.itemModel = itemModel

        let view = NSHostingView(rootView: PasswordManagementNoteItemView().environmentObject(itemModel))
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
        })

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

    private func doSaveNote(_ note: SecureVaultModels.Note) {
        let isNew = note.id == nil

        do {
            guard let storedNoteID = try secureVault?.storeNote(note),
                  let storedNote = try secureVault?.noteFor(id: storedNoteID) else { return }

            itemModel?.cancel()
            if isNew {
                refetchWithText(searchField.stringValue) { [weak self] in
                    self?.syncModelsOnNote(storedNote, select: true)
                }
            } else {
                syncModelsOnNote(storedNote)
            }
            postChange()

        } catch {
            // Which errors can occur when saving notes?
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
                self.refreshData()

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
                self.refreshData()

            default:
                break // cancel, do nothing
            }

        }
    }

    private func promptToDelete(note: SecureVaultModels.Note) {
        guard let window = self.view.window,
              let id = note.id else { return }

        let alert = NSAlert.passwordManagerConfirmDeleteNote()
        alert.beginSheetModal(for: window) { response in

            switch response {
            case .alertFirstButtonReturn:
                try? self.secureVault?.deleteNoteFor(noteId: id)
                self.refreshData()

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
                self.refreshData()

            default:
                break // cancel, do nothing
            }

        }
    }

    private func refreshData() {
        self.itemModel?.clearSecureVaultModel()
        self.refetchWithText(self.searchField.stringValue)
        self.postChange()
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
                    guard let credentials = try? self?.secureVault?.websiteCredentialsFor(accountId: id) else { return }
                    self?.createLoginItemView()
                    self?.syncModelsOnCredentials(credentials)
                case .card:
                    guard let card = try? self?.secureVault?.creditCardFor(id: id) else { return }
                    self?.createCreditCardItemView()
                    self?.syncModelsOnCreditCard(card)
                case .identity:
                    guard let identity = try? self?.secureVault?.identityFor(id: id) else { return }
                    self?.createIdentityItemView()
                    self?.syncModelsOnIdentity(identity)
                case .note:
                    guard let note = try? self?.secureVault?.noteFor(id: id) else { return }
                    self?.createNoteItemView()
                    self?.syncModelsOnNote(note)
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

    private func createNewSecureVaultItemMenu() -> NSMenu {
        let menu = NSMenu()

        func createMenuItem(title: String, action: Selector, imageName: String) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, target: self, keyEquivalent: "")
            item.image = NSImage(named: imageName)

            return item
        }

        menu.items = [
            createMenuItem(title: UserText.pmNewCard, action: #selector(createNewCreditCard), imageName: "CreditCardGlyph"),
            createMenuItem(title: UserText.pmNewLogin, action: #selector(createNewLogin), imageName: "LoginGlyph"),
            createMenuItem(title: UserText.pmNewIdentity, action: #selector(createNewIdentity), imageName: "IdentityGlyph")
        ]

        return menu
    }

    private func updateFilter() {
        let text = searchField.stringValue.trimmingWhitespace()
        listModel?.filter = text
    }

    private func fetchSecureVaultItems(category: SecureVaultSorting.Category = .allItems, completion: @escaping ([SecureVaultItem]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var items: [SecureVaultItem]

            switch category {
            case .allItems:
                let accounts = (try? self.secureVault?.accounts()) ?? []
                let cards = (try? self.secureVault?.creditCards()) ?? []
                let notes = (try? self.secureVault?.notes()) ?? []
                let identities = (try? self.secureVault?.identities()) ?? []

                items = accounts.map(SecureVaultItem.account) +
                    cards.map(SecureVaultItem.card) +
                    notes.map(SecureVaultItem.note) +
                    identities.map(SecureVaultItem.identity)
            case .logins:
                let accounts = (try? self.secureVault?.accounts()) ?? []
                items = accounts.map(SecureVaultItem.account)
            case .identities:
                let identities = (try? self.secureVault?.identities()) ?? []
                items = identities.map(SecureVaultItem.identity)
            case .cards:
                let cards = (try? self.secureVault?.creditCards()) ?? []
                items = cards.map(SecureVaultItem.card)
            }

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

    // MARK: - Empty State

    private func updateEmptyState(state: PasswordManagementItemListModel.EmptyState?) {
        guard let listModel = listModel else {
            return
        }

        if isEditing || state == nil || state == PasswordManagementItemListModel.EmptyState.none {
            hideEmptyState()
        } else {
            showEmptyState(category: listModel.sortDescriptor.category)
        }
    }

    private func showEmptyState(category: SecureVaultSorting.Category) {
        switch category {
        case .allItems: showDefaultEmptyState()
        case .logins: showEmptyState(imageName: "LoginsEmpty", title: UserText.pmEmptyStateLoginsTitle)
        case .identities: showEmptyState(imageName: "IdentitiesEmpty", title: UserText.pmEmptyStateIdentitiesTitle)
        case .cards: showEmptyState(imageName: "CreditCardsEmpty", title: UserText.pmEmptyStateCardsTitle)
        }
    }

    private func hideEmptyState() {
        emptyState.isHidden = true
    }

    private func showDefaultEmptyState() {
        emptyState.isHidden = false
        emptyStateMessage.isHidden = false
        emptyStateButton.isHidden = false

        emptyStateImageView.image = NSImage(named: "LoginsEmpty")

        emptyStateTitle.attributedStringValue = NSAttributedString.make(UserText.pmEmptyStateDefaultTitle, lineHeight: 1.14, kern: -0.23)
        emptyStateMessage.attributedStringValue = NSAttributedString.make(UserText.pmEmptyStateDefaultDescription, lineHeight: 1.05, kern: -0.08)
    }

    private func showEmptyState(imageName: String, title: String) {
        emptyState.isHidden = false

        emptyStateImageView.image = NSImage(named: imageName)
        emptyStateTitle.attributedStringValue = NSAttributedString.make(title, lineHeight: 1.14, kern: -0.23)
        emptyStateMessage.isHidden = true
        emptyStateButton.isHidden = true
    }

}

extension PasswordManagementViewController: NSMenuDelegate {

    func menuNeedsUpdate(_ menu: NSMenu) {
        if let lockItem = menu.items.first(where: { $0.action == #selector(toggleLock(_:)) }) {
            let authenticator = DeviceAuthenticator.shared
            if authenticator.shouldAutoLockLogins {
                lockItem.isHidden = false
                lockItem.title = authenticator.requiresAuthentication ? UserText.passwordManagementUnlock : UserText.passwordManagementLock
            } else {
                lockItem.isHidden = true
            }
        }
    }

}

extension PasswordManagementViewController: NSTextFieldDelegate {

    func controlTextDidChange(_ obj: Notification) {
        updateFilter()
    }

}

extension PasswordManagementViewController: NSTextViewDelegate {

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        if let link = link as? URL, let pane = PreferencePaneIdentifier(url: link) {
            WindowControllersManager.shared.showPreferencesTab(withSelectedPane: pane)
            self.dismiss()

            Pixel.fire(.passwordManagerLockScreenPreferencesButtonPressed)
        }

        return true
    }

    func textView(_ textView: NSTextView,
                  willChangeSelectionFromCharacterRange oldSelectedCharRange: NSRange,
                  toCharacterRange newSelectedCharRange: NSRange) -> NSRange {
        return NSRange(location: 0, length: 0)
    }

}
