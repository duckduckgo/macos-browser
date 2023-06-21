//
//  ContinueSetUpView.swift
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

extension HomePage.Views {

    struct ContinueSetUpView: View {

        @EnvironmentObject var model: HomePage.Models.ContinueSetUpModel

        var body: some View {
            ZStack {
                VStack {
                    HStack {
                        NextStepsView()
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.vertical, -25)
                .padding(.leading, 1)
                VStack(spacing: 20) {
                    if #available(macOS 12.0, *) {
                        LazyVStack(spacing: 4) {
                            FeaturesGrid()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        FeaturesGrid()
                    }
                }
            }
            .visibility(model.hasContent ? .visible : .gone)
        }

        struct FeaturesGrid: View {

            @EnvironmentObject var model: HomePage.Models.ContinueSetUpModel

            var body: some View {
                if #available(macOS 12.0, *) {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(model.itemWidth), spacing: model.horizontalSpacing), count: model.itemsPerRow),
                        spacing: model.verticalSpacing
                    ) {
                        ForEach(model.visibleFeaturesMatrix.flatMap { $0 }, id: \.self) { feature in
                            FeatureCard(featureType: feature)
                        }
                    }
                    .frame(maxWidth: model.gridWidth)
                } else {
                    ForEach(model.visibleFeaturesMatrix.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: model.horizontalSpacing) {
                            ForEach(model.visibleFeaturesMatrix[index], id: \.self) { feature in
                                FeatureCard(featureType: feature)
                            }
                        }
                        .frame(maxWidth: model.gridWidth, alignment: .leading)
                    }
                }

                MoreOrLess(isExpanded: $model.shouldShowAllFeatures)
                    .padding(.top, 4)
                    .visibility(model.isMoreOrLessButtonNeeded ? .visible : .invisible)
            }
        }

        struct FeatureCard: View {

            @EnvironmentObject var model: HomePage.Models.ContinueSetUpModel

            @State var isHovering = false

            private let featureType: HomePage.Models.FeatureType

            init?(featureType: HomePage.Models.FeatureType) {
                self.featureType = featureType
            }

            var body: some View {
                let icon = {
                    Image(nsImage: featureType.icon)
                        .frame(width: 24, height: 24)
                }
                ZStack {
                    CardTemplate(title: featureType.title, summary: featureType.summary, actionText: featureType.action, icon: icon, width: model.itemWidth, height: model.itemHeight, action: { model.performAction(for: featureType) })
                        .contextMenu(ContextMenu(menuItems: {
                            Button(featureType.action, action: { model.performAction(for: featureType) })
                            Divider()
                            Button(model.deleteActionTitle, action: { model.removeItem(for: featureType) })
                        }))
                    HStack {
                        Spacer()
                        VStack {
                            RemoveIemButton(icon: NSImage(named: "Close")!) {
                                model.removeItem(for: featureType)
                            }
                            .visibility(isHovering ? .visible : .gone)
                            Spacer()
                        }
                    }
                    .padding(6)
                }
                .onHover { isHovering in
                    self.isHovering = isHovering
                }
            }
        }

        struct CardTemplate<Content: View>: View {

            var title: String
            var summary: String
            var actionText: String
            @ViewBuilder var icon: Content
            let width: CGFloat
            let height: CGFloat
            let action: () -> Void

            @State var isHovering = false

            var body: some View {
                ZStack(alignment: .center) {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("HomeFavoritesGhostColor"), style: StrokeStyle(lineWidth: 1.0))
                    ZStack {
                        VStack(spacing: 18) {
                            icon
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

        struct ActionButton: View {
            let title: String
            let action: () -> Void
            let foregroundColor: Color = .clear
            let foregroundColorOnHover: Color = Color("HomeFavoritesHoverColor")
            let foregroundColorOnHoverOnCard: Color = Color("HomeFavoritesBackgroundColor")
            private let titleWidth: Double

            @State var isHovering = false
            @Binding var isHoveringOnCard: Bool {
                didSet {
                    print(isHoveringOnCard)
                }
            }

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

            var body: some View {
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

        struct RemoveIemButton: View {
            let icon: NSImage
            let action: () -> Void
            let foreGroundColor: Color = Color("HomeFavoritesBackgroundColor")
            let foregroundColorOnHover: Color = Color("HomeFavoritesHoverColor")

            @State var isHovering = false

            var body: some View {
                ZStack {
                    Circle()
                        .fill(isHovering ? foregroundColorOnHover : foreGroundColor)
                        .frame(width: 16, height: 16)
                    IconButton(icon: icon, action: action)
                        .foregroundColor(.gray)
                }
                .onHover { isHovering in
                    self.isHovering = isHovering
                }
            }
        }

        struct NextStepsView: View {
            let text = "Next Steps"
            let textWidth: CGFloat
            let backgroundColor = Color(red: 57/255, green: 105/255, blue: 239/255)

            init() {
                textWidth = (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13) as Any]).width
            }

            var body: some View {
                HStack(spacing: 0) {
                    Image("NextStepsLeft")
                        .frame(width: 12, height: 5)
                        .padding(.top, 5)
                    ZStack {
                        Rectangle()
                            .fill(backgroundColor)
                            .frame(width: textWidth, height: 20)
                        Text(text)
                            .foregroundColor(.white)
                    }
                    Image("NextStepsRight")
                        .frame(width: 10, height: 19)
                }
            }
        }
    }
}
