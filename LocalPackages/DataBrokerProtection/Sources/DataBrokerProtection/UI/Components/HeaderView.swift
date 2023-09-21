//
//  DashboardHeaderView.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

struct HeaderView: View {
    let title: String
    let subtitle: String
    let iconName: String
    let iconColor: Color

    var body: some View {
        VStack (spacing: 10) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.title)
                    .bold()
            }
            Text(subtitle)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

struct HeaderView_Previews: PreviewProvider {
    static var previews: some View {

        HeaderView(title: "No Results Found!",
                   subtitle: "We were unable to find any matches with the information you provided.",
                   iconName: "clock.fill",
                   iconColor: .yellow)
        .padding(40)
    }
}
