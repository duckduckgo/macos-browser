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

    @MainActor
    final class AddressBarModel: ObservableObject {

        @Published var shouldShowAddressBar: Bool
        @Published var value: AddressBarTextField.Value = .text("", userTyped: false)

        let tabCollectionViewModel: TabCollectionViewModel
        private(set) lazy var addressBarViewController: AddressBarViewController = createAddressBarViewController()

        private var cancellables = Set<AnyCancellable>()

        init(tabCollectionViewModel: TabCollectionViewModel, privacyConfigurationManager: PrivacyConfigurationManaging) {
            self.tabCollectionViewModel = tabCollectionViewModel
            self.shouldShowAddressBar = privacyConfigurationManager.privacyConfig.isEnabled(featureKey: .newTabSearchField)
            privacyConfigurationManager.updatesPublisher.sink { [weak self, weak privacyConfigurationManager] in
                self?.shouldShowAddressBar = privacyConfigurationManager?.privacyConfig.isEnabled(featureKey: .newTabSearchField) == true
            }
            .store(in: &cancellables)
        }

        func createAddressBarViewController() -> AddressBarViewController! {
            let storyboard = NSStoryboard(name: "NavigationBar", bundle: .main)
            let controller: AddressBarViewController = storyboard.instantiateController(identifier: "AddressBarViewController") { [weak self] coder in
                guard let self else {
                    return nil
                }
                return AddressBarViewController(coder: coder, tabCollectionViewModel: self.tabCollectionViewModel, isBurner: false, popovers: nil)
            }
            controller.loadView()

            let buttonsController: AddressBarButtonsViewController = storyboard.instantiateController(identifier: "AddressBarButtonsViewController") { coder in
                controller.createAddressBarButtonsViewController(coder)
            }
            controller.addAndLayoutChild(buttonsController, into: controller.buttonsContainerView)

            controller.isSearchBox = true
            if !tabCollectionViewModel.isBurner {
                Application.appDelegate.homePageSettingsModel.$customBackground
                    .map(\.?.colorScheme)
                    .sink { colorScheme in
                        switch colorScheme {
                        case .dark:
                            controller.addressBarTextField.homePagePreferredAppearance = NSAppearance(named: .darkAqua)
                        case .light:
                            controller.addressBarTextField.homePagePreferredAppearance = NSAppearance(named: .aqua)
                        default:
                            controller.addressBarTextField.homePagePreferredAppearance = nil
                        }
                    }
                    .store(in: &cancellables)
            }

            controller.addressBarTextField.$value
                .assign(to: \.value, onWeaklyHeld: self)
                .store(in: &cancellables)

            return controller
        }
    }

}
