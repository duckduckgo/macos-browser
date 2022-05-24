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
                        .foregroundColor(Color(.editingPanelColor))
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
                    .disabled(!model.isDirty)
                    .focusable(model.isDirty, action: { model.save() })
                    .keyboardShortcutIfAvailable(.return, modifiers: .command)

            } else {
                Button(UserText.pmDelete) { model.requestDelete()}
                    .buttonStyle(StandardButtonStyle())
                    .focusable(action: { model.requestDelete() })

                Button(UserText.pmEdit) { model.edit() }
                    .buttonStyle(StandardButtonStyle())
                    .focusable(action: { model.edit() })
            }

        }
    }

}

// MARK: - Login Views

private struct UsernameView: View {

    @EnvironmentObject var model: PasswordManagementLoginModel

    @State var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text(UserText.pmUsername)
                .bold()
                .padding(.bottom, itemSpacing)

            let menuProvider = MenuProvider([
                .item(title: UserText.loginCopy) { model.copy(model.username) }
            ])

            if model.isEditing || model.isNew {

                TextField("", text: $model.username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, interItemSpacing)

            } else {

                HStack(spacing: 6) {
                    Text(model.username)
                        .textSelectableIfAvailable()
                        .focusable(menu: menuProvider.createMenu, onCopy: { model.copy(model.username) })

                    if isHovering {
                        Button {
                            model.copy(model.username)
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

enum MenuItem: Identifiable {
    var id: ObjectIdentifier {
        switch self {
        case .item(title: let title, checked: _, action: _):
            return .init(title as NSString)
        case .divider:
            return .init("-" as NSString)
        }
    }

    case item(title: String, checked: Bool = false, action: () -> Void)
    case divider
}
final class MenuResponder: NSObject {
    @objc func menuItemSelected(_ menuItem: NSMenuItem) {
        guard let action = menuItem.representedObject as? () -> Void else {
            assertionFailure("Closure expected")
            return
        }
        action()
    }
}
struct MenuProvider {
    var menuItems: [MenuItem]
    init(_ menuItems: [MenuItem]) {
        self.menuItems = menuItems
    }
}
final class ActionMenu: NSMenu {
    let responder = MenuResponder()
    convenience init() {
        self.init(title: "")
    }
}
extension MenuProvider {

    func createContextMenu() -> some View {
        ForEach(menuItems) { item in
            switch item {
            case .item(title: let title, checked: _, action: let action):
                Button(title, action: action)
            case .divider:
                Divider()
            }
        }
    }

    func createMenu() -> NSMenu {
        let menu = ActionMenu()
        for item in menuItems {
            switch item {
            case .item(title: let title, checked: let checked, action: let action):
                let menuItem = NSMenuItem(title: title, action: #selector(MenuResponder.menuItemSelected), target: menu.responder, keyEquivalent: "")
                menuItem.state = checked ? .on : .off
                menuItem.representedObject = action
                menu.addItem(menuItem)
            case .divider:
                menu.addItem(.separator())
            }
        }
        return menu
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
                            .textSelectableIfAvailable()

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
                    .focusable(action: { isPasswordVisible = !isPasswordVisible })
                    .padding(.trailing, 10)

                }
                .padding(.bottom, interItemSpacing)

            } else {

                HStack(alignment: .center, spacing: 6) {
                    let menuProvider = MenuProvider([
                        .item(title: isPasswordVisible ? UserText.passwordHide : UserText.passwordShow) {
                            isPasswordVisible.toggle()
                        },
                        .item(title: UserText.passwordCopy) { model.copy(model.password) }
                    ])

                    if isPasswordVisible {
                        Text(model.password)
                            .textSelectableIfAvailable()
                            .focusable(menu: menuProvider.createMenu, onCopy: { model.copy(model.password) })
                    } else {
                        Text(model.password.isEmpty ? "" : "••••••••••••")
                            .contextMenu(menuItems: menuProvider.createContextMenu)
                            .focusable(menu: menuProvider.createMenu, onCopy: { model.copy(model.password) })
//                        // TODO: AX actions // swiftlint:disable:this todo
//                            .accessibilityAction {
//                                print("Act")
//                            }
                    }

                    if isHovering || isPasswordVisible {
                        Button {
                            isPasswordVisible = !isPasswordVisible
                        } label: {
                            Image("SecureEyeToggle")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .tooltip(isPasswordVisible ? UserText.passwordHide : UserText.passwordShow)
                    }

                    if isHovering {
                        Button {
                            model.copy(model.password)
                        } label: {
                            Image("Copy")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .tooltip(UserText.passwordCopy)
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
                let menuProvider = MenuProvider([
                    .item(title: UserText.open) { model.openURL(domainURL) },
                    .item(title: UserText.copy) { model.copy(domainURL) }
                ])

                TextButton(model.domain) { model.openURL(domainURL) }
                    .contextMenu(menuItems: menuProvider.createContextMenu)
                    .focusable(menu: menuProvider.createMenu, onCopy: { model.copy(domainURL) })
                    .padding(.bottom, interItemSpacing)

            } else {
                let menuProvider = MenuProvider([
                    .item(title: UserText.copy) { model.copy(model.domain) }
                ])

                Text(model.domain)
                    .contextMenu(menuItems: menuProvider.createContextMenu)
                    .focusable(menu: menuProvider.createMenu, onCopy: { model.copy(model.domain) })
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

                TextField(model.domain.dropWWW(), text: $model.title)
                    .font(.title)

            } else {

                let textFieldValue = model.title.isEmpty ? model.domain.dropWWW() : model.title
                let menuProvider = MenuProvider([
                    .item(title: UserText.copy) { model.copy(textFieldValue) }
                ])

                Text(textFieldValue)
                    .font(.title)
                    .textSelectableIfAvailable()
                    .focusable(menu: menuProvider.createMenu, onCopy: { model.copy(textFieldValue) })

            }

        }

    }

}
