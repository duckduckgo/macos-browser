//
//  UIMapper.swift
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

struct MapperToUI {

    func mapToUI(_ dataBroker: DataBroker, extractedProfile: ExtractedProfile) -> DBPUIDataBrokerProfileMatch {
        DBPUIDataBrokerProfileMatch(
            dataBroker: mapToUI(dataBroker),
            name: extractedProfile.fullName ?? "No name",
            addresses: extractedProfile.addresses?.map(mapToUI) ?? [],
            alternativeNames: extractedProfile.alternativeNames ?? [String](),
            relatives: extractedProfile.relatives ?? [String]()
        )
    }

    func mapToUI(_ dataBroker: DataBroker) -> DBPUIDataBroker {
        DBPUIDataBroker(name: dataBroker.name)
    }

    func mapToUI(_ address: AddressCityState) -> DBPUIUserProfileAddress {
        DBPUIUserProfileAddress(street: address.fullAddress, city: address.city, state: address.state, zipCode: nil)
    }
}
