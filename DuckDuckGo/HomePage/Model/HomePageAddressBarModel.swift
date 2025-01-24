//
//  HomePageAddressBarModel.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import BrowserServicesKit
import Combine
import Foundation

extension HomePage.Models {

    /**
     * This class is responsible for exposing Address Bar logic to `AddressBarTextFieldView`
     * that's an `NSViewRepresentable`-wrapped `AddressBarTextField` view.
     *
     * It manages an instance of `AddressBarViewController` and `AddressBarButtonsViewController`
     * and serves as a facade for the API needed by SwiftUI views.
     */
    @MainActor
    final class AddressBarModel: ObservableObject {

        @Published var shouldShowAddressBar: Bool = false {
            didSet {
                if shouldShowAddressBar != oldValue {
                    if shouldShowAddressBar {
                        addressBarViewController = createAddressBarViewController()
                    } else {
                        addressBarViewController = nil
                        addressBarViewControllerCancellables.removeAll()
                    }
                }
            }
        }
        @Published var value: AddressBarTextField.Value = .text("", userTyped: false) {
            didSet {
                if shouldDisplayInitialPlaceholder && !value.string.isEmpty {
                    shouldDisplayInitialPlaceholder = false
                }
            }
        }

        /**
         * This property is a workaround for placeholder not being displayed on the address bar in SwiftUI until focused.
         *
         * It's cleared after first edit on the field.
         */
        @Published var shouldDisplayInitialPlaceholder = true

        var addressBarTextField: AddressBarTextField? {
            guard shouldShowAddressBar else {
                return nil
            }
            return addressBarViewController?.addressBarTextField
        }

        var isSuggestionsWindowVisible: Bool {
            guard shouldShowAddressBar else {
                return false
            }
            return addressBarViewController?.isSuggestionsWindowVisible == true
        }

        func hideSuggestionsWindow() {
            guard shouldShowAddressBar, isSuggestionsWindowVisible else {
                return
            }
            addressBarTextField?.hideSuggestionWindow()
        }

        func escapeKeyDown() -> Bool {
            guard shouldShowAddressBar else {
                return false
            }
            return addressBarViewController?.escapeKeyDown() == true
        }

        func makeView() -> NSView {
            guard shouldShowAddressBar else {
                return NSView()
            }
            guard let addressBarViewController else {
                assertionFailure("addressBarViewController is nil")
                return NSView()
            }
            return addressBarViewController.view
        }

        func setUpExperimentIfNeeded() {
            if isExperimentActive {
                let ntpExperiment = NewTabPageSearchBoxExperiment()
                shouldShowAddressBar = ntpExperiment.cohort?.isExperiment == true
            }
        }

        private weak var tabCollectionViewModel: TabCollectionViewModel?

        private var isExperimentActive: Bool = false {
            didSet {
                setUpExperimentIfNeeded()
            }
        }
        private var privacyConfigCancellable: AnyCancellable?
        private var addressBarViewControllerCancellables = Set<AnyCancellable>()

        init(tabCollectionViewModel: TabCollectionViewModel, privacyConfigurationManager: PrivacyConfigurationManaging) {
            self.tabCollectionViewModel = tabCollectionViewModel
            isExperimentActive = privacyConfigurationManager.privacyConfig.isEnabled(featureKey: .newTabSearchField)
            setUpExperimentIfNeeded()

            privacyConfigCancellable = privacyConfigurationManager.updatesPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self, weak privacyConfigurationManager] in
                    self?.isExperimentActive = privacyConfigurationManager?.privacyConfig.isEnabled(featureKey: .newTabSearchField) == true
                }
        }

        private lazy var addressBarViewController: AddressBarViewController? = createAddressBarViewController()

        private func createAddressBarViewController() -> AddressBarViewController? {
            let viewController = instantiateFromStoryboard()
            subscribeToTextFieldValue(viewController)
            subscribeToCustomBackground(viewController)
            return viewController
        }

        private func instantiateFromStoryboard() -> AddressBarViewController {
            let storyboard = NSStoryboard(name: "NavigationBar", bundle: .main)
            let viewController: AddressBarViewController = storyboard
                .instantiateController(identifier: "AddressBarViewController") { [weak self] coder in
                    guard let self, let tabCollectionViewModel else { return nil }
                    return AddressBarViewController(
                        coder: coder,
                        tabCollectionViewModel: tabCollectionViewModel,
                        burnerMode: tabCollectionViewModel.burnerMode,
                        popovers: nil,
                        isSearchBox: true
                    )
                }

            viewController.loadView()

            let buttonsViewController: AddressBarButtonsViewController = storyboard
                .instantiateController(identifier: "AddressBarButtonsViewController") { coder in
                    viewController.createAddressBarButtonsViewController(coder)
                }

            viewController.addAndLayoutChild(buttonsViewController, into: viewController.buttonsContainerView)
            return viewController
        }

        private func subscribeToTextFieldValue(_ viewController: AddressBarViewController) {
            viewController.addressBarTextField.$value
                .assign(to: \.value, onWeaklyHeld: self)
                .store(in: &addressBarViewControllerCancellables)
        }

        private func subscribeToCustomBackground(_ viewController: AddressBarViewController) {
            guard let tabCollectionViewModel, !tabCollectionViewModel.isBurner else {
                return
            }

            Application.appDelegate.homePageSettingsModel.$customBackground
                .map(\.?.colorScheme)
                .sink { colorScheme in
                    switch colorScheme {
                    case .dark:
                        viewController.addressBarTextField.homePagePreferredAppearance = NSAppearance(named: .darkAqua)
                    case .light:
                        viewController.addressBarTextField.homePagePreferredAppearance = NSAppearance(named: .aqua)
                    default:
                        viewController.addressBarTextField.homePagePreferredAppearance = nil
                    }
                }
                .store(in: &addressBarViewControllerCancellables)
        }
    }
}
