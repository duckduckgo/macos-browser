//
//  ProfileViewModel.swift
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

final class ProfileViewModel: ObservableObject {
    final class Name: Identifiable, ObservableObject {
        let id = UUID()
        @Published var firstName = ""
        @Published var middleName: String? = ""
        @Published var lastName = ""
        @Published var suffix: String? = ""
    }

    final class Address: Identifiable {
        let id = UUID()
        var street: String? = ""
        var city = ""
        var state =  ""
    }

    @Published var names = [Name]()
    @Published var birthYear: Int?
    @Published var addresses = [Address]()

    @Published var selectedName: Name?

    var isBirthdayValid: Bool {
        birthYear != nil
    }

    var isNameValid: Bool {
        names.count > 0
    }

    init() {
        // Create 4 fake profiles with unique names
        let profileNames = ["John Doe", "Jane Smith", "Peter Parker", "Alice Johnson"]
        for name in profileNames {
            let fakeProfile = Name()
            let components = name.components(separatedBy: " ")
            fakeProfile.firstName = components.first ?? ""
            fakeProfile.lastName = components.last ?? ""
            names.append(fakeProfile)
        }

        // Create 3 fake addresses with unique names
        let addressNames = ["123 Main St", "456 Elm St", "789 Oak St"]
        for name in addressNames {
            let fakeAddress = Address()
            fakeAddress.street = name
            fakeAddress.city = "Some City"
            fakeAddress.state = "Sample State"
            addresses.append(fakeAddress)
        }
    }
}
