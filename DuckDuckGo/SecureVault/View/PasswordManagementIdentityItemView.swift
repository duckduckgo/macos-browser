//
//  PasswordManagementIdentityItemView.swift
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

import SwiftUI
import BrowserServicesKit

private let interItemSpacing: CGFloat = 18
private let itemSpacing: CGFloat = 13

struct PasswordManagementIdentityItemView: View {

    @EnvironmentObject var model: PasswordManagementIdentityModel

    var body: some View {

        if model.identity != nil {

            let editMode = model.isEditing || model.isNew

            ZStack(alignment: .top) {
                Spacer()

                if editMode {

                    RoundedRectangle(cornerRadius: 8)
                        .foregroundColor(Color(NSColor.editingPanelColor))
                        .shadow(radius: 6)

                }

                VStack {

                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 10) {

                            HeaderView()
                                .padding(.bottom, editMode ? 20 : 30)

                            IdentificationView()

                            AddressView()

                            ContactInfoView()

                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    }

                    Spacer(minLength: 0)

                    Buttons()
                        .padding(.top, 10)

                }
                .padding()

            }
            .padding(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 10))

        }

    }

}

private struct IdentificationView: View {

    @EnvironmentObject var model: PasswordManagementIdentityModel

    var body: some View {

        VStack(alignment: .leading, spacing: 0) {
            let editMode = model.isEditing || model.isNew

            if !model.firstName.isEmpty || !model.middleName.isEmpty || !model.lastName.isEmpty || editMode {
                Text(UserText.pmIdentification)
                    .bold()
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)
            }

            EditableIdentityField(textFieldValue: $model.firstName, title: UserText.pmFirstName)
            EditableIdentityField(textFieldValue: $model.middleName, title: UserText.pmMiddleName)
            EditableIdentityField(textFieldValue: $model.lastName, title: UserText.pmLastName)
        }

    }

}

private struct AddressView: View {

    @EnvironmentObject var model: PasswordManagementIdentityModel

    var body: some View {

        VStack(alignment: .leading, spacing: 0) {
            if !model.addressStreet.isEmpty ||
                !model.addressCity.isEmpty ||
                !model.addressProvince.isEmpty ||
                !model.addressPostalCode.isEmpty ||
                model.isInEditMode {
                Text("Address")
                    .bold()
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)
            }

            EditableIdentityField(textFieldValue: $model.addressStreet, title: UserText.pmAddressStreet)
            EditableIdentityField(textFieldValue: $model.addressCity, title: UserText.pmAddressCity)
            EditableIdentityField(textFieldValue: $model.addressProvince, title: UserText.pmAddressProvince)
            EditableIdentityField(textFieldValue: $model.addressPostalCode, title: UserText.pmAddressPostalCode)

            if model.isInEditMode {
                Text("Country")
                    .bold()
                    .padding(.bottom, 5)

                Picker("", selection: $model.addressCountryCode) {
                    ForEach(CountryList.countries, id: \.self) { country in
                        Text(country.name)
                            .tag(country.countryCode)
                    }
                }
                .labelsHidden()
                .padding(.bottom, 5)
            } else if !model.addressCountryCode.isEmpty {
                Text("Country")
                    .bold()
                    .padding(.bottom, 5)

                Text(CountryList.name(forCountryCode: model.addressCountryCode) ?? "")
                    .padding(.bottom, interItemSpacing)
            }
        }

    }

}

private struct ContactInfoView: View {

    @EnvironmentObject var model: PasswordManagementIdentityModel

    var body: some View {

        VStack(alignment: .leading, spacing: 0) {
            if !model.homePhone.isEmpty || !model.mobilePhone.isEmpty || !model.emailAddress.isEmpty || model.isInEditMode {
                Text("Contact Info")
                    .bold()
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)
            }

            EditableIdentityField(textFieldValue: $model.homePhone, title: UserText.pmPhoneNumber)
            EditableIdentityField(textFieldValue: $model.emailAddress, title: UserText.pmEmailAddress)
        }

    }

}

// MARK: - Generic Views

private struct HeaderView: View {

    @EnvironmentObject var model: PasswordManagementIdentityModel

    var body: some View {

        HStack(alignment: .center, spacing: 0) {

            Image("Identity")
                .padding(.trailing, 10)

            if model.isNew || model.isEditing {

                TextField("", text: $model.title)
                    .font(.title)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.accentColor, lineWidth: 2)
                    )

            } else {

                Text(model.title)
                    .font(.title)

            }

        }

    }

}

private struct Buttons: View {

    @EnvironmentObject var model: PasswordManagementIdentityModel

    var body: some View {
        HStack {

            if model.isEditing && !model.isNew {
                Button(UserText.pmDelete) {
                    model.requestDelete()
                }
                .buttonStyle(StandardButtonStyle())
            }

            Spacer()

            if model.isEditing || model.isNew {
                Button(UserText.pmCancel) {
                    model.cancel()
                }
                .buttonStyle(StandardButtonStyle())

                Button(UserText.pmSave) {
                    model.save()
                }
                .disabled(!model.isDirty)
                .buttonStyle(DefaultActionButtonStyle(enabled: model.isDirty))

            } else {
                Button(UserText.pmDelete) {
                    model.requestDelete()
                }
                .buttonStyle(StandardButtonStyle())

                Button(UserText.pmEdit) {
                    model.edit()
                }
                .buttonStyle(StandardButtonStyle())

            }

        }
    }

}

private struct EditableIdentityField: View {

    @EnvironmentObject var model: PasswordManagementIdentityModel

    @State var isHovering = false
    @Binding var textFieldValue: String

    let title: String

    var body: some View {
        // Only show fields if the model is either editing or has data to show
        if model.isInEditMode || !textFieldValue.isEmpty {

            VStack(alignment: .leading, spacing: 0) {

                Text(title)
                    .bold()
                    .padding(.bottom, 5)

                if model.isEditing || model.isNew {

                    TextField("", text: $textFieldValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.bottom, interItemSpacing)

                } else {

                    HStack(spacing: 6) {
                        Text(textFieldValue)

                        if isHovering {
                            Button {
                                model.copy(textFieldValue)
                            } label: {
                                Image("Copy")
                            }.buttonStyle(PlainButtonStyle())
                        }

                        Spacer()
                    }
                    .padding(.bottom, interItemSpacing)
                }

            }
            .onHover {
                isHovering = $0
            }

        }
    }

}
