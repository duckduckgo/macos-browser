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

public struct SiteTroubleshootingView: View {

    static let iconSize = CGFloat(16)

    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var model: Model

    @EnvironmentObject
    private var tipsModel: VPNTipsModel

    // MARK: - View Contents

    public var body: some View {
        if let siteInfo = model.siteInfo {
            siteTroubleshootingView(siteInfo)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func siteTroubleshootingView(_ siteInfo: ActiveSiteInfo) -> some View {
        Divider()
            .padding(EdgeInsets(top: 5, leading: 9, bottom: 5, trailing: 9))

        VStack(alignment: .leading) {
            Text(UserText.networkProtectionSiteTroubleShootingViewTitle)
                .applySectionHeaderAttributes(colorScheme: colorScheme)
                .padding(.vertical, 3)
                .padding(.horizontal, 9)

            Toggle(isOn: Binding(get: {
                siteInfo.excluded
            }, set: { value in
                if #available(macOS 14.0, *) {
                    tipsModel.handleSiteExcluded()
                }

                model.setExclusion(value, forDomain: siteInfo.domain)
            })) {
                HStack(spacing: 5) {
                    if let icon = siteInfo.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: Self.iconSize, height: Self.iconSize)
                    }

                    Text(String(format: UserText.networkProtectionSiteTroubleShootingViewExcludeWebsite, siteInfo.domain))
                        .applyLabelAttributes(colorScheme: colorScheme)

                    Spacer()
                }
                .padding(.bottom, 5)
            }.padding(.horizontal, 9)
        }
    }
}
