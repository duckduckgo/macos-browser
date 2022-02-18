//
//  HomepageView.swift
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

extension Homepage.Views {

struct RootView: View {

    var body: some View {

        GeometryReader { geometry in
            ZStack {
                Group {
                    ScrollView {
                        VStack(spacing: 0) {
                            ProtectionSummary()

                            Favorites()
                                .frame(maxWidth: 512)
                                .padding(.top, max(48, geometry.size.height * 0.29))

                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                DefaultBrowserPrompt()
            }
            .frame(maxWidth: .infinity)
            .background(Color("NewTabPageBackgroundColor"))
        }
     }

}

}
