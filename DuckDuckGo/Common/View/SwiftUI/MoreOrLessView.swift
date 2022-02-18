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

struct MoreOrLess: View {

    let moreIsUp: Bool

    @Binding var expanded: Bool

    var upRotation: Double {
        moreIsUp ? 0 : 180
    }

    var downRotation: Double {
        moreIsUp ? 180 : 0
    }

    var body: some View {

        HStack {
            Text(expanded ? UserText.moreOrLessCollapse : UserText.moreOrLessExpand)
            Group {
                if #available(macOS 11.0, *) {
                    Image(systemName: "chevron.up")
                } else {
                    Text("^")
                }
            }
            .rotationEffect(.degrees(expanded ? upRotation : downRotation))
        }
        .font(.system(size: 11, weight: .light))
        .foregroundColor(.secondary)
        .link {
            withAnimation {
                expanded = !expanded
            }
        }

    }

}
