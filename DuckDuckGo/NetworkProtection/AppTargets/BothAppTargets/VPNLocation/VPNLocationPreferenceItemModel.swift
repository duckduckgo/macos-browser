//
//  VPNLocationPreferenceItemModel.swift
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
import NetworkProtection

final class VPNLocationPreferenceItemModel: ObservableObject {
    enum LocationIcon {
        case defaultIcon
        case emoji(String)
    }

    let title: String
    let subtitle: String?
    let icon: LocationIcon

    // This is preloaded so the user doesn't have to wait for the list to load on presentation
    let locationsViewModel = VPNLocationViewModel()

    init(selectedLocation: VPNSettings.SelectedLocation) {
        switch selectedLocation {
        case .nearest:
            title = UserText.vpnLocationNearestAvailable
            subtitle = UserText.vpnLocationNearestAvailableSubtitle
            icon = .defaultIcon
        case .location(let location):
            let countryLabelsModel = NetworkProtectionVPNCountryLabelsModel(country: location.country)
            title = countryLabelsModel.title
            subtitle = selectedLocation.location?.city
            icon = .emoji(countryLabelsModel.emoji)
        }
    }
}
