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
import Combine

private let interItemSpacing: CGFloat = 20
private let itemSpacing: CGFloat = 6

struct PasswordManagementLoginItemView: View {

    @EnvironmentObject var model: PasswordManagementLoginModel

    var body: some View {

        if model.credentials != nil {

            let editMode = model.isEditing || model.isNew

            ZStack(alignment: .top) {
                Spacer()

                if editMode {

                    RoundedRectangle(cornerRadius: 8)
                        .foregroundColor(Color(.editingPanel))
                        .shadow(radius: 6)

                }

                VStack(alignment: .leading, spacing: 0) {

                    ScrollView(.vertical) {
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

                            NotesView()

                            if !model.isEditing && !model.isNew {
                                DatesView()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    }

                    Spacer(minLength: 0)

                    if model.isEditing {
                        Divider()
                    }

                    Buttons()
                        .padding(.top, editMode ? 12 : 10)
                        .padding(.bottom, editMode ? 12 : 3)
                        .padding(.horizontal)

                }
            }
            .padding(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 10))
            .alert(isPresented: $model.isShowingAddressUpdateConfirmAlert) {
                let btnLabel = Text(model.toggleConfirmationAlert.button)
                let btnAction = model.togglePrivateEmailStatus
                let button = Alert.Button.default(btnLabel, action: btnAction)
                let cancelBtnLabel = Text(UserText.cancel)
                let cancelBtnAction = { model.refreshprivateEmailStatusBool() }
                let cancelButton = Alert.Button.cancel(cancelBtnLabel, action: cancelBtnAction)
                return Alert(
                    title: Text(model.toggleConfirmationAlert.title),
                    message: Text(model.toggleConfirmationAlert.message),
                    primaryButton: button,
                    secondaryButton: cancelButton
                )
            }
            .accessibility(identifier: "Login item View")
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
    @State private var isPrivateEmailEnabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text(UserText.pmUsername)
                .bold()
                .padding(.bottom, itemSpacing)

            if model.isEditing || model.isNew {

                TextField("", text: $model.username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, interItemSpacing)
                    .accessibility(identifier: "Username TextField")

            } else {

                HStack(alignment: .top) {
                    UsernameLabel(isHovering: $isHovering)
                    Spacer()
                    if model.shouldShowPrivateEmailToggle {
                        Toggle("", isOn: $model.privateEmailStatusBool)
                            .frame(width: 40)
                            .toggleStyle(.switch)
                    }
                }
            }
        }
        .padding(.bottom, interItemSpacing)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct UsernameLabel: View {

    @EnvironmentObject var model: PasswordManagementLoginModel
    @Binding var isHovering: Bool

    var body: some View {

        VStack(alignment: .leading, spacing: 7) {

            HStack(spacing: 8) {

                if model.usernameIsPrivateEmail {
                    PrivateEmailImage()
                }

                Text(model.username)

                if isHovering && model.username != "" {
                    Button {
                        model.copy(model.username, fieldType: .username)
                    } label: {
                        Image(.copy)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .tooltip(UserText.copyUsernameTooltip)
                }
            }

            PrivateEmailMessage()
        }
    }
}

private struct PrivateEmailActivationButton: View {

    @EnvironmentObject var model: PasswordManagementLoginModel

    var body: some View {
        let status = model.privateEmailStatus
        if model.isSignedIn && (status == .active || status == .inactive) {
            VStack(alignment: .leading) {
                Button(status == .active ? UserText.pmDeactivateAddress : UserText.pmActivateAddress ) {
                    model.isShowingAddressUpdateConfirmAlert = true
                }
                .buttonStyle(StandardButtonStyle())
            }
        }
    }

}

private struct PrivateEmailImage: View {

    @EnvironmentObject var model: PasswordManagementLoginModel

    var image: NSImage? {
        if !model.isSignedIn {
            return nil
        } else {
            switch model.privateEmailStatus {
            case .error:
                return NSImage(imageLiteralResourceName: "Alert-Color-16")
            default:
                return nil
            }

        }
    }

    var body: some View {
        if let image {
            Image(nsImage: image)
                .aspectRatio(contentMode: .fit)
        }
    }
}

private struct PrivateEmailMessage: View {
    @EnvironmentObject var model: PasswordManagementLoginModel

    @State private var hover: Bool = false

    @available(macOS 12, *)
    var attributedString: AttributedString {
        let text = String(format: UserText.pmSignInToManageEmail, UserText.pmEnableEmailProtection)
        var attributedString = AttributedString(text)
        if let range = attributedString.range(of: UserText.pmEnableEmailProtection) {
            attributedString[range].foregroundColor = Color(.linkBlue)
        }
        return attributedString
    }

    var body: some View {
        VStack {
            if model.shouldShowPrivateEmailSignedOutMesage {
                if model.isSignedIn {
                    withAnimation(.easeInOut) {
                        Text(model.privateEmailMessage)
                            .font(.subheadline)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                } else {

                    if #available(macOS 12.0, *) {
                        let combinedText = Text(attributedString)
                            .font(.subheadline)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        combinedText
                            .onTapGesture {
                                model.enableEmailProtection()
                            }
                            .onHover { isHovered in
                                self.hover = isHovered
                                DispatchQueue.main.async {
                                    if hover {
                                        NSCursor.pointingHand.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                }
                            }
                    } else {
                        Text(String(format: UserText.pmSignInToManageEmail, UserText.pmEnableEmailProtection))
                            .font(.subheadline)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .onTapGesture {
                                model.enableEmailProtection()
                            }
                    }
                }
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

                    SecureTextField(textValue: $model.password, isVisible: isPasswordVisible)

                    SecureTextFieldButton(isVisible: $isPasswordVisible, toolTipHideText: UserText.hidePasswordTooltip, toolTipShowText: UserText.showPasswordTooltip)
                    .padding(.trailing, 10)

                }
                .padding(.bottom, interItemSpacing)

            } else {

                HStack(alignment: .center, spacing: 6) {

                    HiddenText(isVisible: isPasswordVisible, text: model.password, hiddenTextLength: 12)

                    if (isHovering || isPasswordVisible) && model.password != "" {
                        SecureTextFieldButton(isVisible: $isPasswordVisible, toolTipHideText: UserText.hidePasswordTooltip, toolTipShowText: UserText.showPasswordTooltip)
                    }

                    if isHovering && model.password != "" {
                        CopyButton {
                            model.copy(model.password, fieldType: .password)
                        }
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
                .accessibility(identifier: "Website TextField")

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

private struct NotesView: View {

    @EnvironmentObject var model: PasswordManagementLoginModel
    let cornerRadius: CGFloat = 8.0
    let borderWidth: CGFloat = 0.4
    let characterLimit: Int = 10000

    var body: some View {
        Text(UserText.pmNotes)
            .bold()
            .padding(.bottom, itemSpacing)

        if model.isEditing || model.isNew {
#if APPSTORE
            FocusableTextEditor(text: $model.notes)
#else
            if #available(macOS 12, *) {
                FocusableTextEditor(text: $model.notes)
            } else {
                TextEditor(text: $model.notes)
                    .frame(height: 197.0)
                    .font(.body)
                    .foregroundColor(.primary)
                    .onChange(of: model.notes) {
                        model.notes = String($0.prefix(characterLimit))
                    }
                    .padding(EdgeInsets(top: 3.0, leading: 6.0, bottom: 5.0, trailing: 0.0))
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius,
                                                style: .continuous))
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Color(.textEditorBorder), lineWidth: borderWidth)
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(Color(.textEditorBackground))
                        }
                    )
            }
#endif
        } else {
            Text(model.notes)
                .padding(.bottom, interItemSpacing)
                .fixedSize(horizontal: false, vertical: true)
                .contextMenu(ContextMenu(menuItems: {
                    Button(UserText.copy, action: {
                        model.copy(model.notes)
                    })
                }))
                .modifier(TextSelectionModifier())
        }
    }

}

private struct TextSelectionModifier: ViewModifier {

    func body(content: Content) -> some View {
        if #available(macOS 12, *) {
            content
                .textSelection(.enabled)
        } else {
            content
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

    private func getIconLetters() -> String {
        return !model.title.isEmpty ? model.title :
               !model.domainTLD.isEmpty ? model.domainTLD :
               "#"
    }

    var body: some View {

        HStack(alignment: .center, spacing: 0) {
            LoginFaviconView(domain: model.domain,
                             generatedIconLetters: getIconLetters())
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

/// Needed to override TextEditor background
extension NSTextView {
  open override var frame: CGRect {
    didSet {
      backgroundColor = .clear
      drawsBackground = true
    }
  }
}
