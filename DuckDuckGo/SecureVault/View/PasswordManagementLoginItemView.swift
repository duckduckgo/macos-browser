//
//  PasswordManagementLoginItemView.swift
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
import SwiftUIExtensions

private let interItemSpacing: CGFloat = 23
private let itemSpacing: CGFloat = 13

struct PasswordManagementLoginItemView: View {

    @EnvironmentObject var model: PasswordManagementLoginModel

    var body: some View {

        if model.credentials != nil {

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

                    if model.isEditing || model.isNew {
                        Divider()
                            .padding(.bottom, 10)
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
            .padding(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 10))

        }

    }

}

// MARK: - Generic Views

private struct Buttons: View {

    @EnvironmentObject var model: PasswordManagementLoginModel

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
                .buttonStyle(DefaultActionButtonStyle(enabled: model.isDirty))
                .disabled(!model.isDirty)

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

// MARK: - Login Views

private struct UsernameView: View {

    @EnvironmentObject var model: PasswordManagementLoginModel

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text(UserText.pmUsername)
                .bold()
                .padding(.bottom, itemSpacing)

            if model.isEditing || model.isNew {

                TextField("", text: $model.username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, interItemSpacing)

            } else {

                VStack(alignment: .leading) {

                    UsernameLabel(isHovering: $isHovering)

                    if model.hasValidPrivateEmail && !model.privateEmailRequestInProgress {
                        PrivateEmailActivationButton()
                    }

                }
                .padding(.bottom, interItemSpacing)
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct UsernameLabel: View {

    @EnvironmentObject var model: PasswordManagementLoginModel
    @Binding var isHovering: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 6) {

            if model.usernameIsPrivateEmail {
                PrivateEmailImage()
            }

            VStack(alignment: .leading, spacing: 4) {

                HStack(spacing: 5) {

                    Text(model.username)

                    if isHovering {
                        Button {
                            model.copy(model.username)
                        } label: {
                            Image("Copy")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .tooltip(UserText.copyUsernameTooltip)
                    }
                }

                if model.hasValidPrivateEmail && model.privateEmailMessage != "" {
                    Text(model.privateEmailMessage)
                        .font(.caption)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }.frame(minHeight: 35)
    }
}

private struct PrivateEmailActivationButton: View {

    @EnvironmentObject var model: PasswordManagementLoginModel

    var body: some View {
        let status = model.privateEmailStatus
        if status == .active || status == .inactive {
            VStack(alignment: .leading) {
                Button(status == .active ? UserText.pmDeactivate : UserText.pmActivate ) {
                    status == .active ? model.requestDelete() : model.requestDelete()
                }
                .buttonStyle(StandardButtonStyle())
            }
        }
    }

}

private struct PrivateEmailImage: View {

    @EnvironmentObject var model: PasswordManagementLoginModel

    var image: NSImage {
        switch model.privateEmailStatus {
        case .active:
            return NSImage(imageLiteralResourceName: "OptionsButtonMenuEmail")
        case .inactive:
            return NSImage(imageLiteralResourceName: "OptionsButtonMenuEmailDisabled")
        case .notFound:
            return NSImage(imageLiteralResourceName: "WarningColored")
        default:
            return NSImage(imageLiteralResourceName: "Error")
        }
    }

    var body: some View {
        ZStack {

            RoundedRectangle(cornerRadius: 4)
                .fill(Color("BlackWhite100").opacity(0.06))
                .frame(width: 24, height: 24)

            if model.privateEmailRequestInProgress {
                ActivityIndicator(isAnimating: $model.privateEmailRequestInProgress, style: .spinning)
            } else {
                Image(nsImage: image)
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
}

private struct PasswordView: View {

    @EnvironmentObject var model: PasswordManagementLoginModel

    @State var isHovering = false
    @State var isPasswordVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text(UserText.pmPassword)
                .bold()
                .padding(.bottom, itemSpacing)

            if model.isEditing || model.isNew {

                HStack {

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
                    .tooltip(isPasswordVisible ? UserText.hidePasswordTooltip : UserText.showPasswordTooltip)
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
                        }
                        .buttonStyle(PlainButtonStyle())
                        .tooltip(isPasswordVisible ? UserText.hidePasswordTooltip : UserText.showPasswordTooltip)
                    }

                    if isHovering {
                        Button {
                            model.copy(model.password)
                        } label: {
                            Image("Copy")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .tooltip(UserText.copyPasswordTooltip)
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

private struct WebsiteView: View {

    @EnvironmentObject var model: PasswordManagementLoginModel

    var body: some View {

        Text(UserText.pmWebsite)
            .bold()
            .padding(.bottom, itemSpacing)

        if model.isEditing || model.isNew {

            TextField("", text: $model.domain)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.bottom, interItemSpacing)

        } else {
            if let domainURL = model.domain.url {
                TextButton(model.domain) {
                    model.openURL(domainURL)
                }
                .padding(.bottom, interItemSpacing)
            } else {
                Text(model.domain)
                    .padding(.bottom, interItemSpacing)
            }
        }

    }

}

private struct DatesView: View {

    @EnvironmentObject var model: PasswordManagementLoginModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer()

            HStack {
                Text(UserText.pmLoginAdded)
                    .bold()
                    .opacity(0.6)
                Text(model.createdDate)
                    .opacity(0.6)
            }

            HStack {
                Text(UserText.pmLoginLastUpdated)
                    .bold()
                    .opacity(0.6)
                Text(model.lastUpdatedDate)
                    .opacity(0.6)
            }

            Spacer()
        }
    }

}

private struct HeaderView: View {

    @EnvironmentObject var model: PasswordManagementLoginModel

    var body: some View {

        HStack(alignment: .center, spacing: 0) {

            LoginFaviconView(domain: model.domain)
                .padding(.trailing, 10)

            if model.isNew || model.isEditing {

                TextField(model.domain, text: $model.title)
                    .font(.title)

            } else {

                Text(model.title.isEmpty ? model.domain : model.title)
                    .font(.title)

            }

        }

    }

}
