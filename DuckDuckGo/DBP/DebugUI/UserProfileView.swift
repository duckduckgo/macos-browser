//
//  UserProfileView.swift
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

import SwiftUI
import Combine
import DataBrokerProtection

struct UserProfileView: View {
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var middleName: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var age: String = ""

    @State private var firstNameError: String = ""
    @State private var middleNameError: String = ""
    @State private var lastNameError: String = ""
    @State private var cityError: String = ""
    @State private var stateError: String = ""
    @State private var ageError: String = ""
    @State var isSaveAlertOn = false

    @State private var isSaveDisabled: Bool = true

    private let userDataKey = "UserData"
    let dataManager: DataBrokerProtectionDataManager

    private struct FieldData {
        let label: String
        let binding: Binding<String>
        let value: String
        let validateFunction: (String) -> Void
        let error: String
    }

    private func validateTextField(label: String,
                                   text: Binding<String>,
                                   value: String,
                                   validationFunction: @escaping (String) -> Void, error: String) -> some View {
        return HStack(alignment: .firstTextBaseline) {
            Text(label)
                .frame(width: 80, alignment: .leading)
            VStack {
                TextField("", text: text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onReceive(Just(value)) { newValue in
                        validationFunction(newValue)
                    }
                Text(error)
                    .foregroundColor(.red)
            }
        }
    }

    var textFields: some View {
        VStack {
            validateTextField(label: "First Name",
                              text: $firstName,
                              value: firstName,
                              validationFunction: validateFirstName,
                              error: firstNameError)

            validateTextField(label: "Middle Name",
                              text: $middleName,
                              value: middleName,
                              validationFunction: validateLastName,
                              error: middleNameError)

            validateTextField(label: "Last Name",
                              text: $lastName,
                              value: lastName,
                              validationFunction: validateLastName,
                              error: lastNameError)

            validateTextField(label: "City",
                              text: $city,
                              value: city,
                              validationFunction: validateCity,
                              error: cityError)

            validateTextField(label: "State",
                              text: $state,
                              value: state,
                              validationFunction: validateState,
                              error: stateError)

            validateTextField(label: "Age",
                              text: $age,
                              value: age,
                              validationFunction: validateAge,
                              error: ageError)
        }
    }

    var body: some View {
        VStack {
            textFields
            let button = Button {
                saveData()
            } label: {
                Text("Save")
            }
            .disabled(isSaveDisabled)

            if #available(macOS 12, *) {
                button.alert("Profile Saved", isPresented: $isSaveAlertOn) {
                    Button("OK", role: .cancel) { }
                }
            }
        }
        .padding()
        .onAppear(perform: {
            restoreData()
        })
    }

    private func validateFirstName(_ value: String) {
        if value.isEmpty {
            firstNameError = "First name must not be empty."
        } else {
            firstNameError = ""
        }
        validateSaveButton()
    }

    private func validateLastName(_ value: String) {
        if value.isEmpty {
            lastNameError = "Last name must not be empty."
        } else {
            lastNameError = ""
        }
        validateSaveButton()
    }

    private func validateCity(_ value: String) {
        if value.isEmpty {
            cityError = "City must not be empty."
        } else {
            cityError = ""
        }
        validateSaveButton()
    }

    private func validateState(_ value: String) {
        if value.isEmpty {
            stateError = "State must not be empty."
        } else {
            stateError = ""
        }
        validateSaveButton()
    }

    private func validateAge(_ value: String) {
        if Int(value) != nil {
            ageError = ""
        } else {
            ageError = "Invalid Age."
        }
        validateSaveButton()
    }

    private func validateSaveButton() {
        isSaveDisabled = firstName.isEmpty || lastName.isEmpty || city.isEmpty || state.isEmpty || age.isEmpty || !ageError.isEmpty
    }

    private func saveData() {
        let name = DataBrokerProtectionProfile.Name(firstName: firstName, lastName: lastName, middleName: middleName)
        let address = DataBrokerProtectionProfile.Address(city: city, state: state)

        let profile = DataBrokerProtectionProfile(names: [name],
                                                  addresses: [address],
                                                  phones: [String](),
                                                  age: Int(age)!)

        dataManager.saveProfile(profile)
        isSaveAlertOn = true
    }

    func restoreData() {
         let profile = dataManager.fetchProfile()
            firstName = profile?.names.first?.firstName ?? ""
            lastName = profile?.names.first?.lastName ?? ""
            city = profile?.addresses.first?.city ?? ""
            state = profile?.addresses.first?.state ?? ""

        if let profileAge = profile?.age {
            age = String("\(profileAge)")
        } else {
            age = ""
        }
    }
}
