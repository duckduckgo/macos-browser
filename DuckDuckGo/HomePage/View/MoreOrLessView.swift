//
//  MoreOrLessView.swift
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
extension HomePage.Views {

    struct MoreOrLess: View {

        @Binding var isExpanded: Bool

        var body: some View {

            HStack(spacing: 20) {

                VStack {
                    Divider()
                        .foregroundColor(Color("HomePageMoreOrLessTextColor"))
                }.frame(maxWidth: .infinity)

                HStack {
                    Text(isExpanded ? UserText.moreOrLessCollapse : UserText.moreOrLessExpand)
                    Group {
                        if #available(macOS 11.0, *) {
                            Image("HomeArrowUp")
                        } else {
                            Text("^")
                        }
                    }
                    .rotationEffect(.degrees(isExpanded ? 0 : 180))
                }
                .foregroundColor(Color("HomePageMoreOrLessTextColor"))

                VStack {
                    Divider()
                        .foregroundColor(Color("HomePageMoreOrLessTextColor"))
                }.frame(maxWidth: .infinity)
            }
            .frame(height: 32)
            .font(.system(size: 11))
            .link {
                withAnimation {
                    isExpanded = !isExpanded
                }
            }

        }

    }

}
