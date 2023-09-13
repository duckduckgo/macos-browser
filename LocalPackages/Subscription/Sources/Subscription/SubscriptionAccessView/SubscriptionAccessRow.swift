//
//  SubscriptionAccessRow.swift
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
import SwiftUIExtensions

public struct SubscriptionAccessRow: View {
    let name: String
    let description: String
    let isExpanded: Bool

    @State var fullHeight: CGFloat = 0.0

    public init(name: String, description: String, isExpanded: Bool) {
        self.name = name
        self.description = description
        self.isExpanded = isExpanded
    }

    public var body: some View {
        VStack(alignment: .leading) {

            HStack(alignment: .center, spacing: 8) {
                Image("SubscriptionIcon")
                    .padding(4)
                    .background(Color.black.opacity(0.06))
                    .cornerRadius(4)

//                TextMenuItemCaption(text: name)
                Text(name)

                Spacer()
                    .contentShape(Rectangle())

                if #available(macOS 11.0, *) {
                    Image(systemName: "chevron.down")
                        .rotationEffect(Angle(degrees: isExpanded ? -180 : 0))
                }
            }
            .drawingGroup()

            VStack(alignment: .leading) {
                Text(description)
                    .fixMultilineScrollableText()

//                TextMenuItemCaption(text: description)
//                    .font(Preferences.Const.Fonts.preferencePaneDisclaimer)

                Button("Action") { }
                    .fixedSize()
                    .frame(alignment: .top)
                    .transaction { t in
                        t.animation = nil
                    }
            }
            .background(
                GeometryReader { proxy in
                    Color.clear.onAppear {
                        fullHeight = proxy.size.height
                        print("Height = \(fullHeight)")
                    }
                }
            )
            .transaction { t in
                t.animation = nil
            }
            .frame(maxHeight: isExpanded ? fullHeight : 0, alignment: .top)
            .clipped()
//            .animation(.easeOut.speed(3.0))
            .opacity(isExpanded ? 1.0 : 0.0)
        }
    }
}
