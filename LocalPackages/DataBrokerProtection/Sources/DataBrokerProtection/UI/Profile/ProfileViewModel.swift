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
    private let dataManager: DataBrokerProtectionDataManaging

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
        @Trimmed var zip =  ""

        internal init(street: String = "", city: String, state: String, zip: String = "") {
            self.street = street
            self.city = city
            self.state = state
            self.zip = zip
        }

        var fullAddress: String {
            let components = [street, zip, city, state].filter { !$0.isEmpty }
            return components.joined(separator: ", ")
        }
    }

    @Published var names = [Name]()
    @Published var birthYear: Int?
    @Published var addresses = [Address]()

    @Published var selectedName: Name?
    @Published var selectedAddress: Address?

    static let defaultSuffixSelection = "No suffix"
    static let defaultStateSelection = ""

    let states = [ProfileViewModel.defaultStateSelection, "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"]

    let suffixes =  [ProfileViewModel.defaultSuffixSelection, "Jr", "Sr", "I", "II", "III", "IV"]

    let birthdayYearRange = (Date().year - 110)...ProfileViewModel.minimumBirthYear

    static let minimumBirthYear = Date().year - 18

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

    init(dataManager: DataBrokerProtectionDataManaging) {
        self.dataManager = dataManager
        restoreSavedProfile()
    }

    func saveName(id: UUID?, firstName: String, middleName: String?, lastName: String, suffix: String?) {
        let chosenSuffix = suffix == ProfileViewModel.defaultSuffixSelection ? nil : suffix

        if let id = id, let name = names.filter({ $0.id == id}).first {
            name.firstName = firstName
            name.middleName = middleName ?? ""
            name.lastName = lastName
            name.suffix = chosenSuffix ?? ""
        } else {
            let name = Name(firstName: firstName,
                            middleName: middleName ?? "",
                            lastName: lastName,
                            suffix: chosenSuffix ?? "")
            names.append(name)
        }
    }

    func deleteName(_ id: UUID) {
        names.removeAll(where: {$0.id == id})
    }

    func saveAddress(id: UUID?, street: String? = nil, city: String, state: String, zip: String? = nil) {
        if let id = id, let address = addresses.filter({ $0.id == id}).first {
            address.street = street ?? ""
            address.city = city
            address.state = state
            address.zip = zip ?? ""
        } else {
            let address = Address(street: street ?? "",
                                  city: city,
                                  state: state,
                                  zip: zip ?? "")
            addresses.append(address)
        }
    }

    func deleteAddress(_ id: UUID) {
        addresses.removeAll(where: {$0.id == id})
    }

    func saveProfile() {
        // It should edit or delete the profile before saving if there was a previous profile saved
        dataManager.saveProfile(profile)
    }

    private func restoreSavedProfile() {
        if let profile = dataManager.fetchProfile() {
            names =  profile.names.map {
                Name(firstName: $0.firstName,
                     middleName: $0.middleName ?? "",
                     lastName: $0.lastName,
                     suffix: $0.suffix ?? "")
            }

            addresses = profile.addresses.map {
                Address(street: $0.street ?? "",
                        city: $0.city,
                        state: $0.state,
                        zip: $0.zipCode ?? "")
            }

            birthYear = profile.age
        }
    }

    private func mapUIProfileToDataBaseProfile() -> DataBrokerProtectionProfile {
        let names = names.map {
            DataBrokerProtectionProfile.Name(firstName: $0.firstName,
                                             lastName: $0.lastName,
                                             middleName: $0.middleName,
                                             suffix: $0.suffix)
        }

        let addresses = addresses.map {
            DataBrokerProtectionProfile.Address(city: $0.city,
                                                state: $0.state,
                                                street: $0.street)
        }

        return DataBrokerProtectionProfile(names: names,
                                           addresses: addresses,
                                           phones: [],
                                           age: birthYear ?? 0)
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

private extension Date {
    var year: Int {
        let calendar = Calendar.current
        return calendar.component(.year, from: self)
    }
}
