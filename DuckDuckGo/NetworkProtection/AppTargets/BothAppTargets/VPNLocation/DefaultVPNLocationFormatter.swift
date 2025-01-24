//
//  DefaultVPNLocationFormatter.swift
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

import Foundation
import SwiftUI
import NetworkProtection

struct DefaultVPNLocationFormatter: VPNLocationFormatting {
    func emoji(for country: String?,
               preferredLocation someLocation: VPNSettings.SelectedLocation) -> String? {
        if let country {
            return NetworkProtectionVPNCountryLabelsModel(country: country, useFullCountryName: true).emoji
        }

        let preferredLocation = VPNLocationModel(selectedLocation: someLocation)
        switch preferredLocation.icon {
        case .defaultIcon:
            return nil
        case .emoji(let emoji):
            return emoji
        }
    }

    func string(from location: String?,
                preferredLocation someLocation: VPNSettings.SelectedLocation) -> String {
        let preferredLocation = VPNLocationModel(selectedLocation: someLocation)

        if let location {
            return preferredLocation.isNearest ? "\(location) (Nearest)" : location
        }

        return preferredLocation.title
    }

    @available(macOS 12, *)
    func string(from location: String?,
                preferredLocation someLocation: VPNSettings.SelectedLocation,
                locationTextColor: Color,
                preferredLocationTextColor: Color) -> AttributedString {
        let preferredLocation = VPNLocationModel(selectedLocation: someLocation)

        if let location {
            var attributedString = AttributedString(
                preferredLocation.isNearest ? "\(location) \(UserText.locationFormatterNearestLocationDescriptor)" : location
            )
            attributedString.foregroundColor = locationTextColor
            if let range = attributedString.range(of: UserText.locationFormatterNearestLocationDescriptor) {
                attributedString[range].foregroundColor = preferredLocationTextColor
            }
            return attributedString
        }

        var attributedString = AttributedString(preferredLocation.title)
        attributedString.foregroundColor = locationTextColor
        return attributedString
    }
}

final class VPNLocationModel: ObservableObject {
    enum LocationIcon {
        case defaultIcon
        case emoji(String)
    }

    let title: String
    let icon: LocationIcon
    let isNearest: Bool

    init(selectedLocation: VPNSettings.SelectedLocation) {
        switch selectedLocation {
        case .nearest:
            title = UserText.locationFormatterNearestLocation
            icon = .defaultIcon
            isNearest = true
        case .location(let location):
            let countryLabelsModel = NetworkProtectionVPNCountryLabelsModel(country: location.country, useFullCountryName: true)
            if let city = location.city {
                title = UserText.locationFormatterLocationFormattedCityAndCountry(
                    city: city,
                    country: countryLabelsModel.title
                )
            } else {
                title = countryLabelsModel.title
            }
            icon = .emoji(countryLabelsModel.emoji)
            isNearest = false
        }
    }
}
