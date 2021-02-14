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

class NavigationBarViewController: NSViewController {

    @IBOutlet weak var goBackButton: NSButton!
    @IBOutlet weak var goForwardButton: NSButton!
    @IBOutlet weak var refreshButton: NSButton!
    @IBOutlet weak var feedbackButton: NSButton!
    @IBOutlet weak var optionsButton: NSButton!

    var addressBarViewController: AddressBarViewController?

    private var tabCollectionViewModel: TabCollectionViewModel

    // swiftlint:disable weak_delegate
    private let goBackButtonMenuDelegate: NavigationButtonMenuDelegate
    private let goForwardButtonMenuDelegate: NavigationButtonMenuDelegate
    // swiftlint:enable weak_delegate

    private var selectedTabViewModelCancellable: AnyCancellable?
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

#if !FEEDBACK

        removeFeedback()

#endif

    }

    @IBSegueAction func createAddressBarViewController(_ coder: NSCoder) -> AddressBarViewController? {
        guard let addressBarViewController = AddressBarViewController(coder: coder,
                                                                      tabCollectionViewModel: tabCollectionViewModel) else {
            os_log("NavigationBarViewController: Failed to init AddressBarViewController", type: .error)
            return nil
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

        selectedTabViewModel.tab.reload()
    }

    @IBAction func optionsButtonAction(_ sender: NSButton) {
        if let event = NSApplication.shared.currentEvent {
            let menu = OptionsButtonMenu(tabCollectionViewModel: tabCollectionViewModel)
            NSMenu.popUpContextMenu(menu, with: event, for: sender)
        }
    }

#if FEEDBACK

    @IBAction func feedbackButtonAction(_ sender: NSButton) {
        let tab = Tab()
        tab.url = URL.feedback
        tabCollectionViewModel.append(tab: tab)
    }

#else

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
        }
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
    }

}
