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

private let interItemSpacing: CGFloat = 16
private let itemSpacing: CGFloat = 10

struct PasswordManagementItemView: View {

    @EnvironmentObject var model: PasswordManagementItemModel

    var body: some View {

        if model.credentials != nil {

            let editMode = model.isEditing || model.isNew

            ZStack(alignment: .top) {
                Spacer()

                if editMode {

                    RoundedRectangle(cornerRadius: 8)
                        .foregroundColor(Color(NSColor.backgroundSecondaryColor))
                        .shadow(radius: 6)

                }

                VStack(alignment: .leading, spacing: 0) {

                    HeaderView()
                        .padding(.bottom, editMode ? 20 : 30)

                    if model.isEditing || model.isNew {
                        Divider()
                            .padding(.bottom, 10)

                        LoginTitleView()
                    }

                    UsernameView()

                    PasswordView()

                    WebsiteView()

                    if !model.isEditing && !model.isNew {
                        DatesView()
                    }

                    Spacer(minLength: 0)

                    Buttons()

                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()

            }
            .padding()
        }

    }

}

private struct Buttons: View {

    @EnvironmentObject var model: PasswordManagementItemModel

    var body: some View {
        HStack {

            if model.isEditing {
                Button("Delete") {
                    model.requestDelete()
                }
            }

            Spacer()

            if model.isEditing || model.isNew {
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

private struct LoginTitleView: View {

    @EnvironmentObject var model: PasswordManagementItemModel

    var body: some View {

        Text("Login Title")
            .bold()
            .padding(.bottom, itemSpacing)

        TextField("", text: $model.title)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.bottom, interItemSpacing)

    }

}

private struct UsernameView: View {

    @EnvironmentObject var model: PasswordManagementItemModel

    @State var isHovering = false

    var body: some View {
        Text("Username")
            .bold()
            .padding(.bottom, itemSpacing)

        if model.isEditing || model.isNew {

            TextField("", text: $model.username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.bottom, interItemSpacing)

        } else {

            HStack(spacing: 6) {
                Text(model.username)

                if isHovering {
                    Button {
                        model.copyUsername()
                    } label: {
                        Image("Copy")
                    }.buttonStyle(PlainButtonStyle())
                }
            }
            .onHover {
                isHovering = $0
            }
            .padding(.bottom, interItemSpacing)

        }

    }

}

private struct PasswordView: View {

    @EnvironmentObject var model: PasswordManagementItemModel

    @State var isHovering = false
    @State var isPasswordVisible = false

    var body: some View {
        Text("Password")
            .bold()
            .padding(.bottom, itemSpacing)

        if model.isEditing || model.isNew {

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
            .padding(.bottom, interItemSpacing)

        } else {

            HStack(alignment: .center, spacing: 6) {

                if isPasswordVisible {
                    Text(model.password)
                } else {
                    Text(model.password.isEmpty ? "" : "••••••••••••")
                }

                if isHovering || isPasswordVisible {
                    Button {
                        isPasswordVisible = !isPasswordVisible
                    } label: {
                        Image("SecureEyeToggle")
                    }.buttonStyle(PlainButtonStyle())
                }

                if isHovering {
                    Button {
                        model.copyPassword()
                    } label: {
                        Image("Copy")
                    }.buttonStyle(PlainButtonStyle())
                }
            }
            .onHover {
                isHovering = $0
            }
            .padding(.bottom, interItemSpacing)

        }
    }

}

private struct WebsiteView: View {

    @EnvironmentObject var model: PasswordManagementItemModel

    var body: some View {

        Text("Website")
            .bold()
            .padding(.bottom, itemSpacing)

        if model.isEditing || model.isNew {

            TextField("", text: $model.domain)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.bottom, interItemSpacing)

        } else {

            Text(model.domain)
                .padding(.bottom, interItemSpacing)

        }

    }

}

private struct DatesView: View {

    @EnvironmentObject var model: PasswordManagementItemModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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
        }
    }

}

private struct HeaderView: View {

    @EnvironmentObject var model: PasswordManagementItemModel

    var body: some View {

        HStack(alignment: .center, spacing: 0) {

            FaviconView(domain: model.domain)
                .padding(.trailing, 10)

            if model.isNew {

                Text("New Login")
                    .font(.title)
                    .padding(.trailing, 4)

            } else {

                if model.isEditing {

                    Text("Edit")
                        .font(.title)
                        .padding(.trailing, 4)

                }

                Text(model.domain)
                    .font(.title)

            }

        }

    }

}
