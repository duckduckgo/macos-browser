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

        @State var isHovering = false {
            didSet {
                moreOrLessButtonVisibility = isHovering && model.isMoreOrLessButtonNeeded ? .visible : .invisible
            }
        }

        @State private var moreOrLessButtonVisibility: ViewVisibility = .invisible

        var body: some View {
            VStack(spacing: 20) {
                SectionTitleView(titleText: model.title, isExpanded: $model.shouldShowAllFeatures, isMoreOrLessButtonVisibility: $moreOrLessButtonVisibility)
                if #available(macOS 12.0, *) {
                    LazyVStack(spacing: 4) {
                        FeaturesGrid()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    FeaturesGrid()
                }
            }
            .onHover { isHovering in
                self.isHovering = isHovering
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
            }
        }

        struct FeatureCard: View {

            @EnvironmentObject var model: HomePage.Models.ContinueSetUpModel

            @State var isHovering = false {
                didSet {
                    model.isHoveringOverItem = isHovering
                }
            }

            private let featureType: HomePage.Models.FeatureType

            init?(featureType: HomePage.Models.FeatureType) {
                self.featureType = featureType
            }

            var body: some View {
                let icon = {
                    Image(nsImage: featureType.icon)
                }
                ZStack {
                    CardTemplate(title: featureType.title, icon: icon, width: model.itemWidth, height: model.itemHeight)
                        .contextMenu(ContextMenu(menuItems: {
                            Button(model.actionTitle(for: featureType), action: { model.performAction(for: featureType) })
                            Divider()
                            Button(model.deleteActionTitle, action: { model.removeItem(for: featureType) })
                        }))
                        .onTapGesture {
                            model.performAction(for: featureType)
                        }
                    HStack {
                        VStack {
                            RemoveIemButton(icon: NSImage(named: "Close")!) {
                                model.removeItem(for: featureType)
                            }
                            .visibility(model.isRemoveItemButtonVisible && isHovering ? .visible : .gone)
                            .padding(-5)
                            Spacer()
                        }
                        Spacer()
                    }
                }
                .onHover { isHovering in
                    self.isHovering = isHovering
                }
            }
        }

        struct RemoveIemButton: View {
            let icon: NSImage
            let action: () -> Void

            var body: some View {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                        .shadow(color: .gray, radius: 1, x: 0, y: 0)
                    IconButton(icon: icon, action: action)
                        .foregroundColor(.black)
                }
            }
        }
    }
}
