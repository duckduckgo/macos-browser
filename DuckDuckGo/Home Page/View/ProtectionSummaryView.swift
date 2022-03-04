//
//  ProtectionSummaryView.swift
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

struct ProtectionSummary: View {

    @EnvironmentObject var model: HomePage.Models.RecentlyVisitedModel

    @Binding var isExpanded: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image("HomeShield")
                .resizable()
                .frame(width: 32, height: 32)
                .onTapGesture(count: 2) {
                    model.showPagesOnHover.toggle()
                }

            Group {
                if model.numberOfTrackersBlocked > 0 {
                    Text(UserText.homePageProtectionSummaryMessage(numberOfTrackersBlocked: model.numberOfTrackersBlocked))
                } else {
                    Text(UserText.homePageProtectionSummaryInfo)
                }
            }
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .font(.system(size: 17, weight: .bold, design: .default))

            Spacer()
                .visibility(isExpanded ? .visible : .gone)

            HoverButton(size: 24, imageName: "HomeArrowUp", imageSize: 16) {
                withAnimation {
                    isExpanded.toggle()
                }
            }.rotationEffect(.degrees(isExpanded ? 0 : 180))
        }
    }

}

}
