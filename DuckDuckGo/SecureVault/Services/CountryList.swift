//
//  CountryList.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

struct CountryList {

    struct Country: Identifiable {
        let id: String
        let name: String

        var countryCode: String {
            return id
        }
    }

    static let countries: [Country] = {
        let codes = Locale.isoRegionCodes

        let countries: [Country] = codes.compactMap { code in
            guard let name = Locale.current.localizedString(forRegionCode: code) else {
                return nil
            }

            return Country(id: code, name: name)
        }

        return countries.sorted { first, second in
            let result = first.name.caseInsensitiveCompare(second.name)
            return result == .orderedAscending
        }
    }()

    static func name(forCountryCode code: String?) -> String? {
        guard let code = code else {
            return nil
        }

        return Locale.current.localizedString(forRegionCode: code)
    }

}
