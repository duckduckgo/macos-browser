//
//  HomePageView.swift
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
import BrowserServicesKit

extension HomePage.Views {

struct RootView: View {

    let backgroundColor = Color("NewTabPageBackgroundColor")
    let targetWidth: CGFloat = 482

    var body: some View {
        ZStack(alignment: .top) {

            ScrollView {
                VStack(spacing: 0) {
                    Group {

                        Favorites()
                            .padding(.top, 72)

                        RecentlyVisited()
                            .padding(.top, 54)
                            .padding(.bottom, 16)

                    }
                    .frame(width: 484)
                }
                .frame(maxWidth: .infinity)
            }

            Rectangle()
                .fill(backgroundColor)
                .mask(LinearGradient(colors: [backgroundColor.opacity(1), backgroundColor.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(height: 16)
                .padding(.trailing, 12) // don't fade the scroll bar
            DefaultBrowserPrompt()
        }
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
     }

}

}
