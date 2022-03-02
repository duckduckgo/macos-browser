//
//  RecentlyVisitedView.swift
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

struct RecentlyVisited: View {

    let dateFormatter = RelativeDateTimeFormatter()

    @EnvironmentObject var model: HomePage.Models.RecentlyVisitedModel

    var body: some View {
        Text("Recently Visited")

        ForEach(model.recentSites, id: \.domain) { site in
            VStack {
                Text(site.domain)
                    .font(.headline)
                Text(site.blockedEntityDisplayNames.joined(separator: " • "))
                    .font(.caption)

                ForEach(site.pages, id: \.url) { page in
                    HStack {
                        Text(page.displayTitle)
                        Text(dateFormatter.localizedString(fromTimeInterval: page.visited.timeIntervalSinceNow))
                    }
                }.padding(.leading, 16)

                Divider()
            }
        }

    }

}

}
