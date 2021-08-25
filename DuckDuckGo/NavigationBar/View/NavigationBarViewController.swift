//
//  NavigationBarViewController.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

import Cocoa
import Combine
import os.log
import BrowserServicesKit

final class NavigationBarViewController: NSViewController {

    @IBOutlet weak var goBackButton: NSButton!
    @IBOutlet weak var goForwardButton: NSButton!
    @IBOutlet weak var refreshButton: NSButton!
    @IBOutlet weak var feedbackButton: NSButton!
    @IBOutlet weak var optionsButton: NSButton!
    @IBOutlet weak var bookmarkListButton: NSButton!
    @IBOutlet weak var shareButton: NSButton!
    @IBOutlet weak var passwordManagementButton: NSButton!

    var addressBarViewController: AddressBarViewController?

    private var tabCollectionViewModel: TabCollectionViewModel

    // swiftlint:disable weak_delegate
    private let goBackButtonMenuDelegate: NavigationButtonMenuDelegate
    private let goForwardButtonMenuDelegate: NavigationButtonMenuDelegate
    // swiftlint:enable weak_delegate

    private lazy var bookmarkListPopover = BookmarkListPopover()
    private lazy var saveCredentialsPopover: SaveCredentialsPopover = SaveCredentialsPopover()
    private lazy var passwordManagementPopover: PasswordManagementPopover = PasswordManagementPopover()

    private var urlCancellable: AnyCancellable?
    private var selectedTabViewModelCancellable: AnyCancellable?
    private var credentialsToSaveCancellable: AnyCancellable?
    private var passwordManagerNotificationCancellable: AnyCancellable?
    private var navigationButtonsCancellables = Set<AnyCancellable>()

    required init?(coder: NSCoder) {
        fatalError("NavigationBarViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel
        goBackButtonMenuDelegate = NavigationButtonMenuDelegate(buttonType: .back, tabCollectionViewModel: tabCollectionViewModel)
        goForwardButtonMenuDelegate = NavigationButtonMenuDelegate(buttonType: .forward, tabCollectionViewModel: tabCollectionViewModel)
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationButtonMenus()
        subscribeToSelectedTabViewModel()
        listenToPasswordManagerNotifications()

        optionsButton.sendAction(on: .leftMouseDown)
        bookmarkListButton.sendAction(on: .leftMouseDown)
        shareButton.sendAction(on: .leftMouseDown)

#if !FEEDBACK

        removeFeedback()

#endif

    }

    @IBSegueAction func createAddressBarViewController(_ coder: NSCoder) -> AddressBarViewController? {
        guard let addressBarViewController = AddressBarViewController(coder: coder,
                                                                      tabCollectionViewModel: tabCollectionViewModel) else {
            fatalError("NavigationBarViewController: Failed to init AddressBarViewController")
        }

        self.addressBarViewController = addressBarViewController
        return addressBarViewController
    }

    @IBAction func goBackAction(_ sender: NSButton) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        selectedTabViewModel.tab.goBack()
    }

    @IBAction func goForwardAction(_ sender: NSButton) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        selectedTabViewModel.tab.goForward()
    }

    @IBAction func refreshAction(_ sender: NSButton) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        Pixel.fire(.refresh(source: .init(sender: sender, default: .button)))
        selectedTabViewModel.tab.reload()
    }

    @IBAction func optionsButtonAction(_ sender: NSButton) {
        let menu = OptionsButtonMenu(tabCollectionViewModel: tabCollectionViewModel)
        menu.actionDelegate = self
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)

        switch menu.result {
        case .bookmarks:
            Pixel.fire(.moreMenu(result: .bookmarksList))
        case .logins:
            Pixel.fire(.moreMenu(result: .logins))
        case .emailProtection:
            Pixel.fire(.moreMenu(result: .emailProtection))
        case .feedback:
            Pixel.fire(.moreMenu(result: .feedback))
        case .fireproof:
            Pixel.fire(.moreMenu(result: .fireproof))
        case .moveTabToNewWindow:
            Pixel.fire(.moreMenu(result: .moveTabToNewWindow))
        case .preferences:
            Pixel.fire(.moreMenu(result: .preferences))
        case .none:
            Pixel.fire(.moreMenu(result: .cancelled))

        case .emailProtectionOff,
             .emailProtectionCreateAddress,
             .bookmarkThisPage,
             .favoriteThisPage:
            break
        }
    }

    @IBAction func bookmarksButtonAction(_ sender: NSButton) {
        showBookmarkListPopover()
    }

    @IBAction func passwordManagementButtonAction(_ sender: NSButton) {
        showPasswordManagementPopover()
    }

    @IBAction func shareButtonAction(_ sender: NSButton) {
        guard let url = tabCollectionViewModel.selectedTabViewModel?.tab.content.url else { return }
        let sharing = NSSharingServicePicker(items: [url])
        sharing.delegate = self
        sharing.show(relativeTo: .zero, of: sender, preferredEdge: .minY)
    }

    func listenToPasswordManagerNotifications() {
        passwordManagerNotificationCancellable = NotificationCenter.default.publisher(for: .PasswordManagerChanged).sink { [weak self] _ in
            self?.updatePasswordManagementButton()
        }
    }

    func showBookmarkListPopover() {
        if bookmarkListPopover.isShown {
            bookmarkListPopover.close()
            return
        }

        bookmarkListPopover.show(relativeTo: bookmarkListButton.bounds.insetFromLineOfDeath(), of: bookmarkListButton, preferredEdge: .maxY)
        Pixel.fire(.bookmarksList(source: .button))
    }

    func showPasswordManagementPopover() {
        guard !saveCredentialsPopover.isShown else { return }

        if passwordManagementPopover.isShown {
            passwordManagementPopover.close()
            return
        }

        passwordManagementPopover.show(relativeTo: passwordManagementButton.bounds.insetFromLineOfDeath(),
                                of: passwordManagementButton,
                                preferredEdge: .minY)

        Pixel.fire(.manageLogins(source: .button))
    }

#if !FEEDBACK

    private func removeFeedback() {
        feedbackButton.removeFromSuperview()
    }

#endif

    private func setupNavigationButtonMenus() {
        let backButtonMenu = NSMenu()
        backButtonMenu.delegate = goBackButtonMenuDelegate
        goBackButton.menu = backButtonMenu
        let forwardButtonMenu = NSMenu()
        forwardButtonMenu.delegate = goForwardButtonMenuDelegate
        goForwardButton.menu = forwardButtonMenu
    }

    private func subscribeToSelectedTabViewModel() {
        selectedTabViewModelCancellable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.subscribeToNavigationActionFlags()
            self?.subscribeToCredentialsToSave()
            self?.subscribeToTabUrl()
        }
    }

    private func subscribeToTabUrl() {
        urlCancellable = tabCollectionViewModel.selectedTabViewModel?.tab.$content
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] _ in
                self?.updatePasswordManagementButton()
            })
    }

    private func updatePasswordManagementButton() {
        let url = tabCollectionViewModel.selectedTabViewModel?.tab.content.url

        passwordManagementButton.image = NSImage(named: "PasswordManagement")

        if passwordManagementPopover.viewController.isDirty {
            // Remember to reset this once the controller is not dirty
            passwordManagementButton.image = NSImage(named: "PasswordManagementDirty")
            return
        }

        // We don't want to remove the button if the popever is showing
        if passwordManagementPopover.isShown {
            return
        }

        passwordManagementPopover.viewController.domain = nil
        guard let url = url, let domain = url.host else {
            return
        }
        passwordManagementPopover.viewController.domain = domain
    }

    private func subscribeToCredentialsToSave() {
        credentialsToSaveCancellable = tabCollectionViewModel.selectedTabViewModel?.$credentialsToSave
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] in
                if let credentials = $0 {
                    self?.promptToSaveCredentials(credentials)
                    self?.tabCollectionViewModel.selectedTabViewModel?.credentialsToSave = nil
                }
        })
    }

    private func promptToSaveCredentials(_ credentials: SecureVaultModels.WebsiteCredentials) {
        showSaveCredentialsPopover()
        saveCredentialsPopover.viewController.saveCredentials(credentials)
    }

    private func showSaveCredentialsPopover() {
        passwordManagementButton.isHidden = false

        saveCredentialsPopover.show(relativeTo: passwordManagementButton.bounds.insetFromLineOfDeath(),
                                    of: passwordManagementButton,
                                    preferredEdge: .minY)
    }

    private func subscribeToNavigationActionFlags() {
        navigationButtonsCancellables.forEach { $0.cancel() }
        navigationButtonsCancellables.removeAll()

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            goBackButton.isEnabled = false
            goForwardButton.isEnabled = false
            return
        }
        selectedTabViewModel.$canGoBack.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateNavigationButtons()
        } .store(in: &navigationButtonsCancellables)

        selectedTabViewModel.$canGoForward.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateNavigationButtons()
        } .store(in: &navigationButtonsCancellables)

        selectedTabViewModel.$canReload.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateNavigationButtons()
        } .store(in: &navigationButtonsCancellables)
    }

    private func updateNavigationButtons() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        goBackButton.isEnabled = selectedTabViewModel.canGoBack
        goForwardButton.isEnabled = selectedTabViewModel.canGoForward
        refreshButton.isEnabled = selectedTabViewModel.canReload
        shareButton.isEnabled = selectedTabViewModel.canReload
        shareButton.isEnabled = selectedTabViewModel.tab.content.url ?? .emptyPage != .emptyPage
    }

}

extension NavigationBarViewController: NSSharingServicePickerDelegate {

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker,
                              delegateFor sharingService: NSSharingService) -> NSSharingServiceDelegate? {
        return self
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        if service == nil {
            Pixel.fire(.sharingMenu(result: .cancelled))
        }
    }
}

extension NavigationBarViewController: NSSharingServiceDelegate {

    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        Pixel.fire(.sharingMenu(result: .failure))
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        Pixel.fire(.sharingMenu(result: .success))
    }

}

extension NavigationBarViewController: OptionsButtonMenuDelegate {

    func optionsButtonMenuRequestedBookmarkPopover(_ menu: NSMenu) {
        showBookmarkListPopover()
    }

    func optionsButtonMenuRequestedLoginsPopover(_ menu: NSMenu) {
        showPasswordManagementPopover()
    }

}
