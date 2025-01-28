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

import PreferencesUI_macOS
import SwiftUI
import SwiftUIExtensions

extension Preferences {

    struct SidebarSectionHeader: View {
        let section: PreferencesSectionIdentifier

        var body: some View {
            Group {
                if let name = section.displayName {
                    Text(name)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 3)
                        .font(PreferencesUI_macOS.Const.Fonts.sideBarHeader)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 31, alignment: .leading)
                }
            }
        }
    }

    struct PaneSidebarItem: View {
        let pane: PreferencePaneIdentifier
        let isSelected: Bool
        let action: () -> Void
        @ObservedObject var protectionStatus: PrivacyProtectionStatus

        init(pane: PreferencePaneIdentifier, isSelected: Bool, status: PrivacyProtectionStatus? = nil, action: @escaping () -> Void) {
            self.pane = pane
            self.isSelected = isSelected
            self.action = action
            self.protectionStatus = status ?? PrivacyProtectionStatus.status(for: pane)
        }

        var body: some View {
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(pane.preferenceIconName).frame(width: 16, height: 16)
                    Text(pane.displayName).font(PreferencesUI_macOS.Const.Fonts.sideBarItem)

                    Spacer()

                    if let status = protectionStatus.status {
                        StatusIndicatorView(status: status)
                    }
                }
            }
            .buttonStyle(SidebarItemButtonStyle(isSelected: isSelected))
            .accessibilityIdentifier("PreferencesSidebar.\(pane.id.rawValue)Button")
        }
    }

    enum StatusIndicator: Equatable {
        case alwaysOn
        case on
        case off
        case custom(String)

        var text: String {
            switch self {
            case .alwaysOn:
                return UserText.preferencesAlwaysOn
            case .on:
                return UserText.preferencesOn
            case .off:
                return UserText.preferencesOff
            case .custom(let customText):
                return customText
            }
        }
    }

    struct StatusIndicatorView: View {
        var status: StatusIndicator
        var isLarge: Bool = false

        private var fontSize: CGFloat {
            isLarge ? 13 : 10
        }

        private var circleSize: CGFloat {
            isLarge ? 7 : 5
        }

        var body: some View {
            HStack(spacing: isLarge ? 6 : 4) {
                Circle()
                    .frame(width: circleSize, height: circleSize)
                    .foregroundColor(colorForStatus(status))

                Text(status.text)
                    .font(.system(size: fontSize))
                    .foregroundColor(.secondary)
            }
        }

        private func colorForStatus(_ status: StatusIndicator) -> Color {
            switch status {
            case .on, .alwaysOn:
                return .alertGreen
            case .off:
                return Color.secondary.opacity(0.33)
            case .custom:
                return .orange
            }
        }
    }

    struct TabSwitcher: View {
        @EnvironmentObject var model: PreferencesSidebarModel

        var body: some View {
            NSPopUpButtonView(selection: $model.selectedTabIndex, viewCreator: {
                let button = NSPopUpButton()
                button.font = PreferencesUI_macOS.Const.Fonts.popUpButton
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
            .frame(height: 51)
            .onAppear(perform: model.resetTabSelectionIfNeeded)
        }
    }

    struct Sidebar: View {
        @EnvironmentObject var model: PreferencesSidebarModel

        var body: some View {
            VStack(spacing: 12) {
                TabSwitcher()
                    .environmentObject(model)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(model.sections) { section in
                            SidebarSectionHeader(section: section.id)
                            sidebarSection(section)
                        }
                    }.padding(.bottom, 16)
                }

            }
            .padding(.top, 18)
            .padding(.horizontal, 10)
        }

        @ViewBuilder
        private func sidebarSection(_ section: PreferencesSection) -> some View {
            ForEach(section.panes) { pane in
                PaneSidebarItem(pane: pane,
                                isSelected: model.selectedPane == pane,
                                status: pane == .vpn ? model.vpnProtectionStatus() : nil) {
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

    private struct SidebarItemButtonStyle: ButtonStyle {

        let isSelected: Bool

        @State private var isHovered: Bool = false

        func makeBody(configuration: Self.Configuration) -> some View {

            let bgColor: Color = {
                if isSelected {
                    return .rowHover
                }
                if isHovered {
                    return .buttonMouseOver
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
