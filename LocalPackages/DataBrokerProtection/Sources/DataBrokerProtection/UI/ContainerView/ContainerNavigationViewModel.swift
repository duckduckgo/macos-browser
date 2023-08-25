//
//  ContainerNavigationViewModel.swift
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

final class ContainerNavigationViewModel: ObservableObject {

     enum BodyViewType: CaseIterable {
        case gettingStarted
        case noResults
        case scanStarted
        case results
        case createProfile

        var description: String {
            switch self {
            case .gettingStarted:
                return "Getting Started"
            case .noResults:
                return "No Results Found"
            case .scanStarted:
                return "Scan Started"
            case .results:
                return "Results"
            case .createProfile:
                return "Create Profile"
            }
        }
     }

    // Move this to private set later when we remove the debug dropdown
    // updateNavigation() should be used instead 
    @Published var bodyViewType: BodyViewType = .gettingStarted

    private let dataManager: DataBrokerProtectionDataManaging

    init(dataManager: DataBrokerProtectionDataManaging) {
        self.dataManager = dataManager
        restoreInitialState()
    }

    private func restoreInitialState() {
        if dataManager.fetchProfile() != nil {
            bodyViewType = .createProfile
        } else {
            bodyViewType = .gettingStarted
        }
    }

    var shouldShowHeader: Bool {
        bodyViewType != .createProfile
    }

    func updateNavigation(_ bodyType: BodyViewType) {
        self.bodyViewType = bodyType
    }
}
