//
//  CardView.swift
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

public struct CardTemplate<Content: View>: View {

    var title: String
    var summary: String
    var actionText: String
    @ViewBuilder var icon: () -> Content
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void

    @State var isHovering = false

    public init(title: String, summary: String, actionText: String, @ViewBuilder icon: @escaping () -> Content, width: CGFloat, height: CGFloat, action: @escaping () -> Void, isHovering: Bool = false) {
        self.title = title
        self.summary = summary
        self.actionText = actionText
        self.icon = icon
        self.width = width
        self.height = height
        self.action = action
        self.isHovering = isHovering
    }

    public var body: some View {
        ZStack(alignment: .center) {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color("HomeFavoritesGhostColor"), style: StrokeStyle(lineWidth: 1.0))
            ZStack {
                VStack(spacing: 18) {
                    icon()
                        .frame(alignment: .center)
                    VStack(spacing: 4) {
                        Text(title)
                            .font(.system(size: 13))
                            .bold()
                        Text(summary)
                            .frame(width: 216, alignment: .center)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .font(.system(size: 11))
                            .foregroundColor(Color("GreyTextColor"))
                    }
                    Spacer()
                }
                .frame(width: 208, height: 130)
                VStack {
                    Spacer()
                    ActionButton(title: actionText, isHoveringOnCard: $isHovering, action: action)
                }
                .padding(8)
            }
        }
        .onHover(perform: { isHovering in
            self.isHovering = isHovering
        })
        .frame(width: width, height: height)
    }
}

public struct ActionButton: View {
    let title: String
    let action: () -> Void
    let foregroundColor: Color = .clear
    let foregroundColorOnHover: Color = Color("HomeFavoritesHoverColor")
    let foregroundColorOnHoverOnCard: Color = Color("HomeFavoritesBackgroundColor")
    private let titleWidth: Double

    @State var isHovering = false
    @Binding var isHoveringOnCard: Bool

    init(title: String, isHoveringOnCard: Binding<Bool>, action: @escaping () -> Void) {
        self.title = title
        self.action = action
        self._isHoveringOnCard = isHoveringOnCard
        self.titleWidth = (title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 11) as Any]).width + 14
    }

    private var fillColor: Color {
        if isHovering {
            return foregroundColorOnHover
        }
        if isHoveringOnCard {
            return foregroundColorOnHoverOnCard
        }
        return foregroundColor
    }

    public var body: some View {
        ZStack {
            Rectangle()
                .fill(fillColor)
                .frame(width: titleWidth, height: 23)
                .cornerRadius(5.0)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(Color("LinkBlueColor"))
        }
        .onTapGesture {
            action()
        }
        .onHover { isHovering in
            self.isHovering = isHovering
            if isHovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pointingHand.pop()
            }
        }
    }
}
