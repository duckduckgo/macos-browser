//
//  HomePage.swift
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
import SwiftUIExtensions

/// Namespace declaration
struct HomePage {

    struct Views {
    }

    struct Models {
    }

    // MARK: Constants

    static let favoritesPerRow = 6
    static let favoritesRowCountWhenCollapsed = 1
    static let featuresPerRow = 3
    static let featureRowCountWhenCollapsed = 1
}

// MARK: ReusableViews
extension HomePage.Views {

    struct SectionTitleView: View {
        let titleText: String
        @Binding var isExpanded: Bool
        @Binding var isMoreOrLessButtonVisibility: ViewVisibility

        var body: some View {
            HStack {
                Text(titleText)
                    .frame(alignment: .leading)
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .foregroundColor(Color("HomeFeedTitleColor"))
                Spacer()
                MoreOrLess(isExpanded: $isExpanded)
                    .padding(.top, 2)
                    .visibility(isMoreOrLessButtonVisibility)
            }
        }
    }

    /// Shows a card with gray background which changes color on hovering.
    /// Can have title and icon, just title or just icon
    /// To not have an icon use an EmptyView() in the view builder
    struct CardTemplate<Content: View>: View {

        var title: String?
        @ViewBuilder var icon: Content
        let width: CGFloat
        let height: CGFloat
        let foregroundColor: Color = Color("HomeFavoritesBackgroundColor")
        let foregroundColorOnHover: Color = Color("HomeFavoritesHoverColor")

        @State var isHovering = false

        var body: some View {
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 12)
                    .foregroundColor(isHovering ? foregroundColorOnHover : foregroundColor)
                HStack(spacing: 10) {
                    if let title {
                        Text(title)
                            .frame(width: 100, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .font(.system(size: 11))
                    }
                    icon
                        .frame(alignment: .trailing)
                }
            }
            .frame(width: width, height: height)
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
}
