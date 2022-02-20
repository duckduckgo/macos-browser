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

extension Homepage.Views {

struct ProtectionSummary: View {

    @EnvironmentObject var model: Homepage.Models.RecentlyVisitedModel

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            Image("HomeShield")

            if model.numberOfTrackersBlocked > 0 {
                Text(UserText.homePageProtectionSummaryMessage(numberOfTrackersBlocked: model.numberOfTrackersBlocked,
                                                               numberOfWebsites: model.numberOfWebsites))
                    .fontWeight(.semibold)
            } else {
                Text(UserText.homePageProtectionSummaryInfo)
                    .fontWeight(.semibold)
            }
            
        }
        .foregroundColor(.primary.opacity(0.4))
    }

}

}
