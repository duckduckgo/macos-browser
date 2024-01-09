//
//  VPNLocationViewModel.swift
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

#if NETWORK_PROTECTION

import Foundation
import Combine
import NetworkProtection

final class VPNLocationViewModel: ObservableObject {
    private let locationListRepository: NetworkProtectionLocationListRepository
    private let settings: VPNSettings
    private var selectedLocation: VPNSettings.SelectedLocation
    @Published public var state: LoadingState
    @Published public var isNearestSelected: Bool

    enum ViewAction {
        case cancel
        case submit
    }

    enum LoadingState {
        case loading
        case loaded(countryItems: [VPNCountryItemModel])

        var isLoading: Bool {
            switch self {
            case .loading:
                return true
            case .loaded:
                return false
            }
        }
    }

    init(locationListRepository: NetworkProtectionLocationListRepository, settings: VPNSettings) {
        self.locationListRepository = locationListRepository
        self.settings = settings
        state = .loading
        selectedLocation = settings.selectedLocation
        self.isNearestSelected = selectedLocation == .nearest
    }

    func onViewAppeared() async {
        await reloadList()
    }

    func onNearestItemSelection() async {
        selectedLocation = .nearest
        await reloadList()
    }

    func onCountryItemSelection(id: String, cityId: String? = nil) async {
        let location = NetworkProtectionSelectedLocation(country: id, city: cityId)
        selectedLocation = .location(location)
        await reloadList()
    }

    func onSubmit() {
        settings.selectedLocation = selectedLocation
    }

    @MainActor
    private func reloadList() async {
        guard let list = try? await locationListRepository.fetchLocationList().sorted(by: { lhs, rhs in
            lhs.country.localizedLocationFromCountryCode < rhs.country.localizedLocationFromCountryCode
        }) else { return }
        let isNearestSelected = selectedLocation == .nearest
        var isCurrentItemFirstItem = true

        let countryItems = list.map { currentLocation in
            let isCountrySelected: Bool
            var cityPickerItems: [CityItem]
            let selectedCityItem: CityItem

            switch selectedLocation {
            case .location(let location):
                isCountrySelected = location.country == currentLocation.country
                cityPickerItems = currentLocation.cities.map { currentCity in
                    return CityItem(cityName: currentCity.name)
                }
                selectedCityItem = location.city.flatMap(CityItem.init(cityName:)) ?? .nearest
            case .nearest:
                isCountrySelected = false
                cityPickerItems = currentLocation.cities.map { currentCity in
                    CityItem(cityName: currentCity.name)
                }
                selectedCityItem = .nearest
            }
            let isFirstItem = isCurrentItemFirstItem
            isCurrentItemFirstItem = false

            return VPNCountryItemModel(
                netPLocation: currentLocation,
                isSelected: isCountrySelected,
                cityPickerItems: cityPickerItems,
                selectedCityItem: selectedCityItem,
                isFirstItem: isFirstItem
            )
        }
        self.isNearestSelected = isNearestSelected
        state = .loaded(countryItems: countryItems)
    }
}

private typealias CountryItem = VPNCountryItemModel
private typealias CityItem = VPNCityItemModel

struct VPNCountryItemModel: Identifiable {
    private let labelsModel: NetworkProtectionVPNCountryLabelsModel

    var emoji: String {
        labelsModel.emoji
    }
    var title: String {
        labelsModel.title
    }
    let isSelected: Bool
    var id: String
    let subtitle: String?
    let nearestCityPickerItem: VPNCityItemModel = .nearest
    let cityPickerItems: [VPNCityItemModel]
    let selectedCityItem: VPNCityItemModel
    let shouldShowPicker: Bool
    let isFirstItem: Bool

    fileprivate init(netPLocation: NetworkProtectionLocation, isSelected: Bool, cityPickerItems: [VPNCityItemModel], selectedCityItem: VPNCityItemModel, isFirstItem: Bool = false) {
        self.labelsModel = .init(country: netPLocation.country)
        self.isSelected = isSelected
        self.id = netPLocation.country
        let hasMultipleCities = netPLocation.cities.count > 1
        self.subtitle = hasMultipleCities ? UserText.vpnLocationCountryItemFormattedCitiesCount(netPLocation.cities.count) : nil
        self.cityPickerItems = cityPickerItems
        self.shouldShowPicker = hasMultipleCities
        self.selectedCityItem = selectedCityItem
        self.isFirstItem = isFirstItem
    }
}

struct VPNCityItemModel: Identifiable, Hashable {
    let id: String
    let name: String

    fileprivate init(cityName: String) {
        self.id = cityName
        self.name = cityName
    }
}

extension VPNCityItemModel {
    static var nearest: VPNCityItemModel {
        VPNCityItemModel(cityName: UserText.vpnLocationNearest)
    }
}

extension NetworkProtectionLocationListCompositeRepository {
    convenience init() {
        let settings = VPNSettings(defaults: .netP)
        self.init(
            environment: settings.selectedEnvironment,
            tokenStore: NetworkProtectionKeychainTokenStore(),
            errorEvents: .networkProtectionAppDebugEvents
        )
    }
}

extension VPNLocationViewModel {
    convenience init() {
        let locationListRepository = NetworkProtectionLocationListCompositeRepository()
        self.init(
            locationListRepository: locationListRepository,
            settings: VPNSettings(defaults: .netP)
        )
    }
}

private extension String {
    var localizedLocationFromCountryCode: String {
        Locale.current.localizedString(forRegionCode: self) ?? ""
    }
}

#endif
