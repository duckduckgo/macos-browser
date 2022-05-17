//
//  PreferencesSidebar.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import Carbon.HIToolbox

extension Preferences {

    struct SidebarItem: View {
        @EnvironmentObject var model: PreferencesSidebarModel

        let pane: PreferencePaneIdentifier
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            let textColor = isSelected
                ? (model.isFirstResponder ? Color(.selectedMenuItemTextColor) : Color(.unemphasizedSelectedTextColor))
                : Color(.controlTextColor)

            Button(action: action) {
                HStack(spacing: 6) {
                    Image(pane.preferenceIconName).frame(width: 16, height: 16)
                    Text(pane.displayName)
                        .font(Const.Fonts.sideBarItem)
                        .foregroundColor(textColor)
                }
            }
            .buttonStyle(SidebarItemButtonStyle(isSelected: isSelected))
        }
    }

    struct TabSwitcher: View {
        @EnvironmentObject var model: PreferencesSidebarModel

        var body: some View {
            NSPopUpButtonView(selection: $model.selectedTabIndex, viewCreator: {
                let button = NSPopUpButton()
                button.font = Const.Fonts.popUpButton
                button.setButtonType(.momentaryLight)
                button.isBordered = false

                for (index, type) in model.tabSwitcherTabs.enumerated() {
                    guard let tabTitle = type.title else {
                        assertionFailure("Attempted to display standard tab type in tab switcher")
                        continue
                    }

                    let item = button.menu?.addItem(withTitle: tabTitle, action: nil, keyEquivalent: "")
                    item?.representedObject = index
                }

                return button
            })
            .padding(.horizontal, 3)
            .frame(height: 60)
            .onAppear(perform: model.resetTabSelectionIfNeeded)
        }
    }

    struct Sidebar: View {
        @EnvironmentObject var model: PreferencesSidebarModel

        static let tableViewTag = 157

        var body: some View {
            VStack(spacing: 12) {
                TabSwitcher()
                    .environmentObject(model)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(model.sections) { section in
                            ForEach(section.panes) { pane in
                                SidebarItem(pane: pane, isSelected: model.selectedPane == pane) {
                                    model.selectPane(pane)
                                }
                            }
                            if section != model.sections.last {
                                Color(NSColor.separatorColor)
                                    .frame(height: 1)
                                    .padding(8)
                            }
                        }
                    }
                    .focusable(onClick: true, focusRing: false, tag: Self.tableViewTag, onFocus: { isFirstResponder in
                        if model.isFirstResponder != isFirstResponder {
                            model.isFirstResponder = isFirstResponder
                        }
                    }, keyDown: { event in
                        switch Int(event.keyCode) {
                        case kVK_DownArrow:
                            if NSApp.isCommandPressed || NSApp.isOptionPressed {
                                fallthrough
                            }
                            model.selectNextPane()
                            return nil
                        case kVK_End:
                            model.selectLastPane()
                            return nil
                        case kVK_UpArrow:
                            if NSApp.isCommandPressed || NSApp.isOptionPressed {
                                fallthrough
                            }
                            model.selectPreviousPane()
                            return nil
                        case kVK_Home:
                            model.selectFirstPane()
                            return nil
                        default: break
                        }
                        return event
                    })
                }

            }
            .padding(.top, 18)
            .padding(.horizontal, 20)
        }
    }

    private struct SidebarItemButtonStyle: ButtonStyle {

        let isSelected: Bool

        @State private var isHovered: Bool = false
        @EnvironmentObject var model: PreferencesSidebarModel

        func makeBody(configuration: Self.Configuration) -> some View {

            let bgColor: Color = {
                if isSelected {
                    return model.isFirstResponder ? Color(.selectedContentBackgroundColor) : Color(.unemphasizedSelectedContentBackgroundColor)
                }
                if isHovered {
                    return Color(.rowHoverColor)
                }
                return Color(NSColor.clear.withAlphaComponent(0.001))
            }()

            configuration.label
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .truncationMode(.tail)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(bgColor))
                .onHover { inside in
                    self.isHovered = inside
                }
        }
    }
}
