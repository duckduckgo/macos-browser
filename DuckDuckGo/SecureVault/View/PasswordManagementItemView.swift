//
//  PasswordManagementItemView.swift
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

private struct ShowItemView: View {

    @EnvironmentObject var model: PasswordManagementItemModel

    @State var isHoveringOverUsername = false
    @State var isHoveringOverPassword = false
    @State var isPasswordVisible = false

    var body: some View {

        VStack(alignment: .leading) {

            HStack(alignment: .top, spacing: 10) {

                FaviconView(domain: model.domain)

                Text(model.domain)
                    .font(.title)

                Spacer()

            }
            .padding(.bottom, 30)

            Text("Username")
                .bold()
                .padding(.bottom, 4.5)

            HStack(spacing: 6) {
                Text(model.username)
                if isHoveringOverUsername {
                    Button {
                        model.copyUsername()
                    } label: {
                        Image("Copy")
                    }.buttonStyle(PlainButtonStyle())
                }
            }
            .onHover {
                isHoveringOverUsername = $0
            }
            .padding(.bottom, 20.5)

            Text("Password")
                .bold()
                .padding(.bottom, 4.5)

            HStack(spacing: 6) {

                if isPasswordVisible {
                    Text(model.password)
                } else {
                    Text(model.password.isEmpty ? "" : "••••••••••••")
                }

                if isHoveringOverPassword || isPasswordVisible {
                    Button {
                        isPasswordVisible = !isPasswordVisible
                    } label: {
                        Image("SecureEyeToggle")
                    }.buttonStyle(PlainButtonStyle())
                }

                if isHoveringOverPassword {
                    Button {
                        model.copyPassword()
                    } label: {
                        Image("Copy")
                    }.buttonStyle(PlainButtonStyle())
                }
            }
            .onHover {
                isHoveringOverPassword = $0
            }
            .padding(.bottom, 20.5)

            Text("Website")
                .bold()
                .padding(.bottom, 4.5)

            Text(model.domain)

            Spacer()

            HStack {
                Text("Added")
                    .bold()
                    .opacity(0.5)
                Text(model.createdDate)
                    .opacity(0.5)
            }

            HStack {
                Text("Last Updated")
                    .bold()
                    .opacity(0.5)
                Text(model.lastUpdatedDate)
                    .opacity(0.5)
            }
            .padding(.bottom, 10)

        }
        .padding(EdgeInsets(top: 30, leading: 20, bottom: 0, trailing: 0))
    }

}

private struct EditItemView: View {

    @EnvironmentObject var model: PasswordManagementItemModel

    @State var isPasswordVisible = false

    var body: some View {
        VStack(alignment: .leading) {

            HStack(alignment: .top, spacing: 10) {

                FaviconView(domain: model.domain)

                Text("Edit")
                    .font(.title)

                Text(model.domain)
                    .font(.title)

                Spacer()

            }
            .padding(.bottom, 30)

            Text("Login Title")
                .bold()
                .padding(.bottom, 4)

            TextField("", text: $model.title)
                .padding(.bottom, 10)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Text("Username")
                .bold()
                .padding(.bottom, 4)

            TextField("", text: $model.username)
                .padding(.bottom, 10)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Text("Password")
                .bold()
                .padding(.bottom, 4)

            ZStack(alignment: .trailing) {

                if isPasswordVisible {

                    TextField("", text: $model.password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                } else {

                    SecureField("", text: $model.password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                }

                Button {
                    isPasswordVisible = !isPasswordVisible
                } label: {
                    Image("SecureEyeToggle")
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 10)

            }
            .padding(.bottom, 10)

            Text("Website")
                .bold()
                .padding(.bottom, 4.5)

            Text(model.domain)

            Spacer()

        }
        .padding(EdgeInsets(top: 30, leading: 20, bottom: 0, trailing: 20))
    }

}

struct PasswordManagementItemView: View {

    @EnvironmentObject var model: PasswordManagementItemModel

    var body: some View {

        if model.credentials != nil {

            VStack {

                ZStack {
                    if model.isEditing {
                        EditItemView()
                    } else {
                        ShowItemView()
                    }
                }

                HStack {

                    if model.isEditing {
                        Button("Delete") {
                            print("Delete")
                        }
                    }

                    Spacer()

                    if model.isEditing {
                        Button("Cancel") {
                            print("Cancel")
                            model.cancel()
                        }

                        if #available(macOS 11, *) {
                            Button("Save") {
                                model.save()
                            }
                            .keyboardShortcut(.defaultAction) // macOS 11+
                            .disabled(!model.isDirty)
                        } else {
                            Button("Save") {
                                model.save()
                            }
                            .disabled(!model.isDirty)
                        }

                    } else {
                        Button("Delete") {
                            model.requestDelete()
                        }

                        Button("Edit") {
                            model.edit()
                        }
                    }

                }.padding()

            }

        }

    }

}
