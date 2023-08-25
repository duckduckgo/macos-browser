//
//  SwiftUIWrappers.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import SwiftUI
import DataBrokerProtection
import BrowserServicesKit

final class DataBrokerProfileQueryViewController: NSViewController {
   private let dataManager: DataBrokerProtectionDataManager

    internal init(dataManager: DataBrokerProtectionDataManager) {
        self.dataManager = dataManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let viewModel = DataBrokerProfileQueryViewModel(dataManager: dataManager)

        let hostingController = NSHostingController(rootView: DataBrokerProfileQueryView(viewModel: viewModel))
        view = hostingController.view
    }
}

final class DataBrokerUserProfileViewController: NSViewController {
    private let dataManager: DataBrokerProtectionDataManager

    internal init(dataManager: DataBrokerProtectionDataManager) {
        self.dataManager = dataManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let hostingController = NSHostingController(rootView: UserProfileView(dataManager: dataManager))
        view = hostingController.view
    }
}
