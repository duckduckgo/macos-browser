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

        let editMode = model.isEditing || model.isNew

        ZStack(alignment: .top) {
            Spacer()

            if editMode {

                RoundedRectangle(cornerRadius: 8)
                    .foregroundColor(Color(NSColor.editingPanelColor))
                    .shadow(radius: 6)

            }

            ScrollView(.vertical, showsIndicators: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/) {
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

            // Spacer(minLength: 0)

        }
        .padding(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 10))

        Buttons()
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 26, trailing: 26))
    }

}

private struct IdentificationView: View {

    @EnvironmentObject var model: PasswordManagementIdentityModel

    var body: some View {

        VStack(alignment: .leading, spacing: 0) {
            let editMode = model.isEditing || model.isNew

            if !model.firstName.isEmpty || !model.middleName.isEmpty || !model.lastName.isEmpty || editMode {
                Text("Identification")
                    .bold()
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)
            }

            if !model.firstName.isEmpty || editMode {
                FirstNameView()
            }

            if !model.middleName.isEmpty || editMode {
                MiddleNameView()
            }

            if !model.lastName.isEmpty || editMode {
                LastNameView()
            }
        }

    }

}

private struct AddressView: View {

    @EnvironmentObject var model: PasswordManagementIdentityModel

    @State private var selectedCountry = "Canada"

    let countries: [String] = {
        var countries: [String] = []

        for code in NSLocale.isoCountryCodes as [String] {
            let id = NSLocale.localeIdentifier(fromComponents: [NSLocale.Key.countryCode.rawValue: code])
            let name = NSLocale(localeIdentifier: "en_UK").displayName(forKey: NSLocale.Key.identifier, value: id) ?? "Country not found for code: \(code)"
            countries.append(name)
        }

        return countries.sorted()
    }()

    var body: some View {

        VStack(alignment: .leading, spacing: 0) {
            let editMode = model.isEditing || model.isNew

            if !model.addressStreet.isEmpty || !model.addressCity.isEmpty || !model.addressProvince.isEmpty || !model.addressPostalCode.isEmpty || editMode {
                Text("Address")
                    .bold()
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)
            }

            if !model.addressStreet.isEmpty || editMode {
                AddressStreetView()
            }

            if !model.addressCity.isEmpty || editMode {
                AddressCityView()
            }

            if !model.addressProvince.isEmpty || editMode {
                AddressProvinceView()
            }

            if !model.addressPostalCode.isEmpty || editMode {
                AddressPostalCodeView()
            }

            if editMode {
                Text("Country")
                    .bold()
                    .padding(.bottom, 5)

                Picker("", selection: $selectedCountry) {
                    ForEach(countries, id: \.self) {
                        Text($0)
                    }
                }
                .labelsHidden()
                .padding(.bottom, 5)
            }
        }

    }

}

private struct ContactInfoView: View {

    @EnvironmentObject var model: PasswordManagementIdentityModel

    var body: some View {

        VStack(alignment: .leading, spacing: 0) {
            let editMode = model.isEditing || model.isNew

            if !model.homePhone.isEmpty || !model.mobilePhone.isEmpty || !model.emailAddress.isEmpty || editMode {
                Text("Contact Info")
                    .bold()
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)
            }

            if !model.homePhone.isEmpty || editMode {
                HomePhoneView()
            }

            if !model.mobilePhone.isEmpty || editMode {
                MobilePhoneView()
            }

            if !model.emailAddress.isEmpty || editMode {
                EmailAddressView()
            }
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

            if model.isNew {

                TextField("", text: $model.title)
                    .font(.title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

            } else {

                if model.isEditing {

                    TextField("", text: $model.title)
                        .font(.title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                } else {

                    Text(model.title)
                        .font(.title)

                }

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

// MARK: - Identity Views

private struct FirstNameView: View {

    @EnvironmentObject var model: PasswordManagementIdentityModel

    @State var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text("First Name")
                .bold()
                .padding(.bottom, 5)

            if model.isEditing || model.isNew {

                TextField("", text: $model.firstName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, interItemSpacing)

            } else {

                HStack(spacing: 6) {
                    Text(model.firstName)

                    if isHovering {
                        Button {
                            // model.copyFirstName()
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

private struct MiddleNameView: View {

    @EnvironmentObject var model: PasswordManagementIdentityModel

    @State var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text("Middle Name")
                .bold()
                .padding(.bottom, 5)

            if model.isEditing || model.isNew {

                TextField("", text: $model.middleName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, interItemSpacing)

            } else {

                HStack(spacing: 6) {
                    Text(model.middleName)

                    if isHovering {
                        Button {
                            // model.copyFirstName()
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

private struct LastNameView: View {

    @EnvironmentObject var model: PasswordManagementIdentityModel

    @State var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text("Last Name")
                .bold()
                .padding(.bottom, 5)

            if model.isEditing || model.isNew {

                TextField("", text: $model.lastName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, interItemSpacing)

            } else {

                HStack(spacing: 6) {
                    Text(model.lastName)

                    if isHovering {
                        Button {
                            // model.copyFirstName()
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

private struct AddressStreetView: View {

    @EnvironmentObject var model: PasswordManagementIdentityModel

    @State var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text("Street")
                .bold()
                .padding(.bottom, 5)

            if model.isEditing || model.isNew {

                TextField("", text: $model.addressStreet)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, interItemSpacing)

            } else {

                HStack(spacing: 6) {
                    Text(model.addressStreet)

                    if isHovering {
                        Button {
                            // model.copyFirstName()
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

private struct AddressCityView: View {

    @EnvironmentObject var model: PasswordManagementIdentityModel

    @State var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text("City")
                .bold()
                .padding(.bottom, 5)

            if model.isEditing || model.isNew {

                TextField("", text: $model.addressCity)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, interItemSpacing)

            } else {

                HStack(spacing: 6) {
                    Text(model.addressCity)

                    if isHovering {
                        Button {
                            // model.copyFirstName()
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

private struct AddressProvinceView: View {

    @EnvironmentObject var model: PasswordManagementIdentityModel

    @State var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text("State / Province")
                .bold()
                .padding(.bottom, 5)

            if model.isEditing || model.isNew {

                TextField("", text: $model.addressProvince)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, interItemSpacing)

            } else {

                HStack(spacing: 6) {
                    Text(model.addressProvince)

                    if isHovering {
                        Button {
                            // model.copyFirstName()
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

private struct AddressPostalCodeView: View {

    @EnvironmentObject var model: PasswordManagementIdentityModel

    @State var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text("Postal Code")
                .bold()
                .padding(.bottom, 5)

            if model.isEditing || model.isNew {

                TextField("", text: $model.addressPostalCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, interItemSpacing)

            } else {

                HStack(spacing: 6) {
                    Text(model.addressPostalCode)

                    if isHovering {
                        Button {
                            // model.copyFirstName()
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

private struct HomePhoneView: View {

    @EnvironmentObject var model: PasswordManagementIdentityModel

    @State var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text("Home Phone")
                .bold()
                .padding(.bottom, 5)

            if model.isEditing || model.isNew {

                TextField("", text: $model.homePhone)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, interItemSpacing)

            } else {

                HStack(spacing: 6) {
                    Text(model.homePhone)

                    if isHovering {
                        Button {
                            // model.copyFirstName()
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

private struct MobilePhoneView: View {

    @EnvironmentObject var model: PasswordManagementIdentityModel

    @State var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text("Mobile Phone")
                .bold()
                .padding(.bottom, 5)

            if model.isEditing || model.isNew {

                TextField("", text: $model.mobilePhone)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, interItemSpacing)

            } else {

                HStack(spacing: 6) {
                    Text(model.mobilePhone)

                    if isHovering {
                        Button {
                            // model.copyFirstName()
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

private struct EmailAddressView: View {

    @EnvironmentObject var model: PasswordManagementIdentityModel

    @State var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text("Email Address")
                .bold()
                .padding(.bottom, 5)

            if model.isEditing || model.isNew {

                TextField("", text: $model.emailAddress)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, interItemSpacing)

            } else {

                HStack(spacing: 6) {
                    Text(model.emailAddress)

                    if isHovering {
                        Button {
                            // model.copyFirstName()
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
