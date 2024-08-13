//
//  SiteTroubleshootingView.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import Combine
import Foundation
import SwiftUI

fileprivate extension View {
    func applyCurrentSiteAttributes() -> some View {
        font(.system(size: 13, weight: .regular, design: .default))
    }
}

public struct SiteTroubleshootingView: View {

    // TODO: Remove this.  It's temporary
    let accordionUI = true

    static let iconSize = CGFloat(16)

    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var model: Model

    // MARK: - View Contents

    public var body: some View {
        if model.isFeatureEnabled,
           let siteInfo = model.siteInfo {
            siteTroubleshootingView(siteInfo)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func siteTroubleshootingView(_ siteInfo: SiteTroubleshootingInfo) -> some View {
        if accordionUI {
            mainAccordionView(siteInfo)
        } else {
            if !accordionUI {
                Divider()
                    .padding(EdgeInsets(top: 5, leading: 9, bottom: 5, trailing: 9))
            }

            VStack(alignment: .leading) {
                Text("Website not working?")
                    //.applyCurrentSiteAttributes()
                    .font(.system(size: 13, weight: .bold))
                    .padding(.vertical, 3)
                    .padding(.horizontal, 9)
                    .foregroundColor(Color(.defaultText))

                Toggle(isOn: Binding(get: {
                    siteInfo.excluded
                }, set: { value in
                    model.setExclusion(value, forDomain: siteInfo.domain)
                })) {
                    HStack {
                        Image(nsImage: siteInfo.icon)
                            .resizable()
                            .frame(width: Self.iconSize, height: Self.iconSize)

                        Text("Exclude website from VPN")
                            .font(.system(size: 12))
                            .foregroundColor(Color(.defaultText))

                        Spacer()
                    }
                    .padding(.bottom, 5)
                }.padding(.horizontal, 9)
            }
        }
    }

    @ViewBuilder
    private func mainAccordionView(_ siteInfo: SiteTroubleshootingInfo) -> some View {
        AccordionView { isHovered in
            Image(nsImage: siteInfo.icon)
                .resizable()
                .frame(width: Self.iconSize, height: Self.iconSize)
                .clipShape(RoundedRectangle(cornerRadius: 3.0))
            Text("\(siteInfo.domain) not working?")
                .applyCurrentSiteAttributes()
                .padding(.vertical, 3)
                .foregroundColor(isHovered ? .white : Color(.defaultText))
        } submenu: {
            VStack(alignment: .leading, spacing: 0) {
                Text("Excluding \(siteInfo.domain) might help")
                    .font(.system(size: 12))
                    .foregroundColor(Color(.defaultText))
                    .padding(.horizontal, 9)
                    .padding(.bottom, 4)

                VStack(alignment: .leading, spacing: 0) {
                    exclusionOptionMenuButton(title: "Exclude website from VPN", selected: siteInfo.excluded) {
                        model.setExclusion(true, forDomain: siteInfo.domain)
                    }

                    exclusionOptionMenuButton(title: "Include website in VPN", selected: !siteInfo.excluded) {
                        model.setExclusion(false, forDomain: siteInfo.domain)
                    }
                }.padding(.horizontal, 9)

                manageExclusionsMenuButton(title: "Manage website exclusions...", selected: !siteInfo.excluded) {

                    model.manageExclusions()
                }
            }.padding(.vertical, 6)
                .background(colorScheme == .light ? Color.black.opacity(0.05) : Color.white.opacity(0.05))
        }
    }

    /// Creates a menu button for the site troubleshooting view.
    ///
    @ViewBuilder
    private func exclusionOptionMenuButton(title: String, selected: Bool, action: @escaping () -> Void) -> MenuItemCustomButton<some View> {

        MenuItemCustomButton {
            action()
        } label: { isHovered in
            if selected {
                Image(.accordionViewCheckmark)
                    .resizable()
                    .font(.system(size: 8))
                    .frame(width: Self.iconSize, height: Self.iconSize)
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: Self.iconSize, height: Self.iconSize)
            }

            Text(title)
                .font(.system(size: 12))
                .foregroundColor(isHovered ? .white : Color(.defaultText))
        }
    }

    /// Creates a menu button for the site troubleshooting view.
    ///
    @ViewBuilder
    private func manageExclusionsMenuButton(title: String, selected: Bool, action: @escaping () -> Void) -> MenuItemCustomButton<some View> {

        MenuItemCustomButton {
            action()
        } label: { isHovered in
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(isHovered ? .white : Color(.defaultText))
        }
    }
}
