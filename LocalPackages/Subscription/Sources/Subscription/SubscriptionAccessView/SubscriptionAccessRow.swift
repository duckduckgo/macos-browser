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
    let descriptionHeader: String?
    let description: String
    let isExpanded: Bool
    let buttonTitle: String?
    let buttonAction: (() -> Void)?

    @State var fullHeight: CGFloat = 0.0

    public init(name: String, descriptionHeader: String? = nil, description: String, isExpanded: Bool, buttonTitle: String? = nil, buttonAction: (() -> Void)? = nil) {
        self.name = name
        self.descriptionHeader = descriptionHeader
        self.description = description
        self.isExpanded = isExpanded
        self.buttonTitle = buttonTitle
        self.buttonAction = buttonAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Image("SubscriptionIcon")
                    .padding(4)
                    .background(Color.black.opacity(0.06))
                    .cornerRadius(4)

//                TextMenuItemCaption(text: name)
                Text(name)

                Spacer()
                    .contentShape(Rectangle())

                Image(systemName: "chevron.down")
                    .rotationEffect(Angle(degrees: isExpanded ? -180 : 0))

            }
            .drawingGroup()

            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                    .frame(height: 10)

                if let header = descriptionHeader, !header.isEmpty {
                    Text(header)
                        .bold()
                }

                Text(description)
                    .fixMultilineScrollableText()

                if let title = buttonTitle, let action = buttonAction {
                    Spacer()
                        .frame(height: 8)
                    Button(title) { action() }
                        .buttonStyle(DefaultActionButtonStyle(enabled: true))
                }

                Spacer()
                    .frame(height: 10)
            }
            .background(
                GeometryReader { proxy in
                    Color.clear.onAppear {
                        fullHeight = proxy.size.height
                        print(fullHeight)
                    }
                }
            )
            .transaction { t in
                t.animation = nil
            }
            .frame(maxHeight: isExpanded ? fullHeight : 0, alignment: .top)
            .clipped()
            .opacity(isExpanded ? 1.0 : 0.0)
        }
    }
}
