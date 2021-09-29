//
//  PasswordManagementCreditCardItemView.swift
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

private let interItemSpacing: CGFloat = 23
private let itemSpacing: CGFloat = 13

struct PasswordManagementCreditCardItemView: View {

    @EnvironmentObject var model: PasswordManagementCreditCardModel

    var body: some View {

        let editMode = model.isEditing || model.isNew

        ZStack(alignment: .top) {
            Spacer()

            if editMode {

                RoundedRectangle(cornerRadius: 8)
                    .foregroundColor(Color(NSColor.editingPanelColor))
                    .shadow(radius: 6)

            }

            VStack(alignment: .leading, spacing: 0) {

                HeaderView()
                    .padding(.bottom, editMode ? 20 : 30)

                EditableIdentityField(textFieldValue: $model.cardNumber, title: "Card Number") {
                    print("Copied card number")
                }

                EditableIdentityField(textFieldValue: $model.cardSecurityCode, title: "CVV") {
                    print("Copied card security value")
                }

                if model.isInEditMode {
                    Text("Country")
                        .bold()
                        .padding(.bottom, 5)

                    Picker("", selection: $model.countryCode) {
                        ForEach(CountryList.countries, id: \.self) { country in
                            Text(country.name)
                                .tag(country.countryCode)
                        }
                    }
                    .labelsHidden()
                    .padding(.bottom, 5)
                } else if !model.countryCode.isEmpty {
                    Text("Country")
                        .bold()
                        .padding(.bottom, 5)

                    Text(CountryList.name(forCountryCode: model.countryCode) ?? "")
                        .padding(.bottom, interItemSpacing)
                }

                EditableIdentityField(textFieldValue: $model.postalCode, title: "Postal Code") {
                    print("Copied postal code")
                }

                Spacer(minLength: 0)

                Buttons()

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()

        }
        .padding(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 10))

    }

}

private struct HeaderView: View {

    @EnvironmentObject var model: PasswordManagementCreditCardModel

    var body: some View {

        HStack(alignment: .center, spacing: 0) {

            Image("Note")
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

// MARK: - Generic Views

private struct Buttons: View {

    @EnvironmentObject var model: PasswordManagementCreditCardModel

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

    @EnvironmentObject var model: PasswordManagementCreditCardModel

    @State var isHovering = false
    @Binding var textFieldValue: String

    let title: String
    let copyButtonClosure: () -> Void

    var body: some View {

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
                                copyButtonClosure()
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
