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

private struct PreferencesSidebarItemButtonStyle: ButtonStyle {

    let bgColor: Color

    func makeBody(configuration: Self.Configuration) -> some View {

        configuration.label
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .truncationMode(.tail)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(bgColor))

    }
}

extension Preferences {
    
    struct SidebarItem: View {
        @EnvironmentObject var model: PreferencesModel

        let pane: PreferencePaneIdentifier
        let action: () -> Void
        
        var body: some View {
            let selected = model.selectedPane == pane

            Button(action: action) {
                HStack(spacing: 6) {
                    Image(pane.preferenceIconName).frame(width: 16, height: 16)
                    Text(pane.displayName).font(Const.Fonts.sideBarItem)
                }
            }
            .buttonStyle(selected ?
                         PreferencesSidebarItemButtonStyle(bgColor: Color("RowHoverColor")) :
                            // Almost clear, so that whole view is clickable
                         PreferencesSidebarItemButtonStyle(bgColor: Color(NSColor.windowBackgroundColor.withAlphaComponent(0.001))))
        }
    }

    struct Sidebar: View {
        @EnvironmentObject var model: PreferencesModel

        @State var selectedTab: Tab.TabContent = .newPreferences

        var body: some View {
            VStack(spacing: 12) {
                NSPopUpButtonView<Tab.TabContent>(selection: $selectedTab, viewCreator: {
                    let button = NSPopUpButton()
                    button.font = Const.Fonts.popUpButton
                    button.setButtonType(.momentaryLight)
                    button.isBordered = false
                    
                    for type in Tab.TabContent.displayableTabTypes {
                        guard let tabTitle = type.title else {
                            assertionFailure("Attempted to display standard tab type in tab switcher")
                            continue
                        }
                        
                        let item = button.menu?.addItem(withTitle: tabTitle, action: nil, keyEquivalent: "")
                        item?.representedObject = type
                    }
                    
                    return button
                })
                    .padding(.horizontal, 3)
                    .frame(height: 60)
                
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(model.sections) { section in
                            ForEach(section.panes) { pane in
                                SidebarItem(pane: pane) {
                                    model.selectedPane = pane
                                }
                                .environmentObject(model)
                            }
                            if section != model.sections.last {
                                Color(NSColor.separatorColor)
                                    .frame(height: 1)
                                    .padding(6)
                            }
                        }
                    }
                }

            }
            .padding(.top, 18)
            .padding(.horizontal, 24)
        }
    }

}

typealias Const = Preferences.Const
typealias SidebarItem = Preferences.SidebarItem

struct Sidebar_Previews: PreviewProvider {
    
    static var previews: some View {
        Preferences.Sidebar(model: .init())
            .frame(width: 250)
    }
}
