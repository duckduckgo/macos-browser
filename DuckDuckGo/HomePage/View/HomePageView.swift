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
        let isBurner: Bool

        var body: some View {
            if isBurner {

                BurnerHomePageView()

            } else {
                ZStack(alignment: .top) {

                    ScrollView {
                        VStack(spacing: 0) {
                            Group {
                                DefaultBrowserPrompt()

                                Favorites()
                                    .padding(.top, 72)

                                RecentlyVisited()
                                    .padding(.top, 66)
                                    .padding(.bottom, 16)

                            }
                            .frame(width: 508)
                        }
                        .frame(maxWidth: .infinity)
                    }

                }
                .frame(maxWidth: .infinity)
                .background(backgroundColor)
                .onAppear {
                    LocalBookmarkManager.shared.requestSync()
                }
        }
    }
}

}
