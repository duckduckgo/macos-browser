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

    @EnvironmentObject var model: Model

    // MARK: - View Contents

    public var body: some View {
        if model.isFeatureEnabled,
           let currentSite = model.currentSite {
            siteTroubleshootingView(currentSite)
        } else {
            EmptyView()
        }
    }

    private func siteTroubleshootingView(_ currentSite: CurrentSite) -> some View {
        Group {
            AccordionView { _ in
                Image(nsImage: currentSite.icon)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 3.0))
                Text("\(currentSite.domain) issues?")
                    .applyCurrentSiteAttributes()
            } submenu: {
                VStack {
                    MenuItemCustomButton {
                        model.setExclusion(true, forDomain: currentSite.domain)
                    } label: { _ in
                        HStack {
                            if currentSite.excluded {
                                Image(.accordionViewCheckmark)
                                    .resizable()
                                    .font(.system(size: 13))
                                    .frame(width: 16, height: 16)
                                    .applyCurrentSiteAttributes()
                            } else {
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: 16, height: 16)
                            }
                            Text("Exclude from VPN")
                        }
                    }

                    MenuItemCustomButton {
                        model.setExclusion(false, forDomain: currentSite.domain)
                    } label: { _ in
                        if !currentSite.excluded {
                            Image(.accordionViewCheckmark)
                                .resizable()
                                .font(.system(size: 13))
                                .frame(width: 16, height: 16)
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 16, height: 16)
                        }

                        Text("Route through VPN")
                    }
                }
            }

            Divider()
                .padding(EdgeInsets(top: 5, leading: 9, bottom: 5, trailing: 9))
        }
    }
}
