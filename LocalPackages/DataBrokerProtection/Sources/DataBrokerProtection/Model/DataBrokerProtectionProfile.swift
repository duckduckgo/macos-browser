//
//  DataBrokerProtectionProfile.swift
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

public struct DataBrokerProtectionProfile {
    struct Address {
        let city: String
        let state: String
    }

    struct Name {
        let firstName: String
        let lastName: String
    }

    let names: [Name]
    let addresses: [Address]
    let age: Int
}

internal extension DataBrokerProtectionProfile {
    var profileQueries: [ProfileQuery] {
        return addresses.flatMap { address in
            names.map { name in
                ProfileQuery(
                    firstName: name.firstName,
                    lastName: name.lastName,
                    city: address.city,
                    state: address.state,
                    age: age)
            }
        }
    }
}
