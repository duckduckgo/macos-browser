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

    final class Name: Identifiable {
        let id = UUID()
        @Trimmed var firstName = ""
        @Trimmed var middleName = ""
        @Trimmed var lastName = ""
        @Trimmed var suffix = ""

        var fullName: String {
            let components = [firstName, middleName, lastName, suffix].filter { !$0.isEmpty }
            return components.joined(separator: " ")
        }

        internal init(firstName: String,
                      middleName: String = "",
                      lastName: String,
                      suffix: String = "") {
            self.firstName = firstName
            self.middleName = middleName
            self.lastName = lastName
            self.suffix = suffix
        }
    }

    final class Address: Identifiable {
        let id = UUID()
        @Trimmed var street = ""
        @Trimmed var city = ""
        @Trimmed var state =  ""

        internal init(street: String = "", city: String, state: String) {
            self.street = street
            self.city = city
            self.state = state
        }

        var fullAddress: String {
            let components = [street, city, state].filter { !$0.isEmpty }
            return components.joined(separator: ", ")
        }
    }

    @Published var names = [Name]()
    @Published var birthYear: Int?
    @Published var addresses = [Address]()

    @Published var selectedName: Name?
    @Published var selectedAddress: Address?

    var isBirthdayValid: Bool {
        birthYear != nil
    }

    var isNameValid: Bool {
        names.count > 0
    }

    var isAddressValid: Bool {
        addresses.count > 0
    }

    var isProfileValid: Bool {
        [isBirthdayValid, isNameValid, isAddressValid].allSatisfy { $0 }
    }

    func saveName(id: UUID?, firstName: String, middleName: String?, lastName: String, suffix: String?) {
        if let id = id, let name = names.filter({ $0.id == id}).first {
            name.firstName = firstName
            name.middleName = middleName ?? ""
            name.lastName = lastName
            name.suffix = suffix ?? ""
        } else {
            let name = Name(firstName: firstName,
                            middleName: middleName ?? "",
                            lastName: lastName,
                            suffix: suffix ?? "")
            names.append(name)
        }
    }

    func deleteName(_ id: UUID) {
        names.removeAll(where: {$0.id == id})
    }

    func saveAddress(id: UUID?, street: String? = nil, city: String, state: String) {
        if let id = id, let address = addresses.filter({ $0.id == id}).first {
            address.street = street ?? ""
            address.city = city
            address.state = state
        } else {
            let address = Address(street: street ?? "",
                                  city: city,
                                  state: state)
            addresses.append(address)
        }
    }

    func deleteAddress(_ id: UUID) {
        addresses.removeAll(where: {$0.id == id})
    }

}

@propertyWrapper
struct Trimmed {
    private var value: String

    var wrappedValue: String {
        get { value }
        set { value = newValue.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    init(wrappedValue initialValue: String) {
        value = initialValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
