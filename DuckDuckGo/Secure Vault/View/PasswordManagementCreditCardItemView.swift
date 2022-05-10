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

        if model.card != nil {

            ZStack(alignment: .top) {
                Spacer()

                if model.isInEditMode {

                    RoundedRectangle(cornerRadius: 8)
                        .foregroundColor(Color(NSColor.editingPanelColor))
                        .shadow(radius: 6)

                }

                VStack(alignment: .leading, spacing: 0) {

                    HeaderView()
                        .padding(.bottom, model.isInEditMode ? 20 : 30)

                    EditableCreditCardField(textFieldValue: $model.cardNumber, title: UserText.pmCardNumber)
                    EditableCreditCardField(textFieldValue: $model.cardholderName, title: UserText.pmCardholderName)
                    EditableCreditCardField(textFieldValue: $model.cardSecurityCode, title: UserText.pmCardVerificationValue)

                    // Expiration:

                    if model.expirationMonth != nil || model.expirationYear != nil || model.isInEditMode {
                        Text(UserText.pmCardExpiration)
                            .bold()
                            .padding(.bottom, 5)
                    }

                    if model.isInEditMode {
                        HStack {

                            Picker("", selection: $model.expirationMonth) {
                                ForEach(Date.monthsWithIndex, id: \.self) { month in
                                    Text(month.name)
                                        .tag(month.index as Int?)
                                }
                            }
                            .labelsHidden()

                            Picker("", selection: $model.expirationYear) {
                                ForEach(Date.nextTenYears, id: \.self) { year in
                                    Text(String(year))
                                        .tag(year as Int?)
                                }
                            }
                            .labelsHidden()

                        }
                        .padding(.bottom, interItemSpacing)
                    } else if let month = model.expirationMonth, let year = model.expirationYear {
                        let components = DateComponents(calendar: Calendar.current, year: year, month: month)

                        if let date = components.date {
                            let textFieldValue = PasswordManagementCreditCardModel.dateFormatter.string(from: date)
                            let menuProvider = MenuProvider([
                                .item(title: UserText.copy) { model.copy(textFieldValue) }
                            ])

                            Text(textFieldValue)
                                .textSelectableIfAvailable()
                                .focusable(menu: menuProvider.createMenu, onCopy: { model.copy(textFieldValue) })
                                .padding(.bottom, interItemSpacing)
                        }
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

}

private struct HeaderView: View {

    @EnvironmentObject var model: PasswordManagementCreditCardModel

    var body: some View {

        HStack(alignment: .center, spacing: 0) {

            Image("Card")
                .padding(.trailing, 10)

            if model.isNew || model.isEditing {

                TextField("", text: $model.title)
                    .font(.title)

            } else {

                let menuProvider = MenuProvider([
                    .item(title: UserText.copy) { model.copy(model.title) }
                ])

                Text(model.title)
                    .font(.title)
                    .textSelectableIfAvailable()
                    .focusable(menu: menuProvider.createMenu, onCopy: { model.copy(model.title) })

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
                Button(UserText.pmDelete) { model.requestDelete() }
                    .buttonStyle(StandardButtonStyle())
                    .focusable(action: { model.requestDelete() })
            }

            Spacer()

            if model.isEditing || model.isNew {
                Button(UserText.pmCancel) { model.cancel() }
                    .buttonStyle(StandardButtonStyle())
                    .focusable(action: { model.cancel() })
                    .keyboardShortcutIfAvailable(.escape)
                
                Button(UserText.pmSave) { model.save() }
                    .buttonStyle(DefaultActionButtonStyle(enabled: model.isDirty))
                    .focusable(action: { model.save() })
                    .keyboardShortcutIfAvailable(.return, modifiers: .command)
                    .disabled(!model.isDirty)

            } else {
                Button(UserText.pmDelete) { model.requestDelete() }
                    .buttonStyle(StandardButtonStyle())
                    .focusable(action: { model.requestDelete() })

                Button(UserText.pmEdit) { model.edit() }
                    .buttonStyle(StandardButtonStyle())
                    .focusable(action: { model.edit() })

            }

        }
    }

}

private struct EditableCreditCardField: View {

    @EnvironmentObject var model: PasswordManagementCreditCardModel

    @State var isHovering = false
    @Binding var textFieldValue: String

    let title: String

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
                        let menuProvider = MenuProvider([
                            .item(title: UserText.copy) { model.copy(textFieldValue) }
                        ])

                        Text(textFieldValue)
                            .textSelectableIfAvailable()
                            .focusable(menu: menuProvider.createMenu, onCopy: { model.copy(textFieldValue) })

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
