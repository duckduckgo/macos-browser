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
import PixelKit

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
                .padding(.top, -24)
                .padding(.leading, 2)
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

                HomePage.Views.MoreOrLess(isExpanded: $model.shouldShowAllFeatures)
                    .padding(.top, -3)
                    .visibility(model.isMoreOrLessButtonNeeded ? .visible : .gone)
            }
        }

        struct FeatureCard: View {

            @EnvironmentObject var model: HomePage.Models.ContinueSetUpModel

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
                    HomePage.Views.ContinueSetUpView.CardTemplate(title: featureType.title, summary: featureType.summary, actionText: featureType.action, confirmationText: featureType.confirmation, icon: icon, width: model.itemWidth, height: model.itemHeight, action: { model.performAction(for: featureType) })
                        .contextMenu(ContextMenu(menuItems: {
                            Button(featureType.action, action: { model.performAction(for: featureType) })
                            Divider()
                            Button(model.deleteActionTitle, action: { model.removeItem(for: featureType) })
                        }))
                    HStack {
                        Spacer()
                        VStack {
                            HomePage.Views.CloseButton(icon: .close, size: 16) {
                                model.removeItem(for: featureType)
                            }
                            Spacer()
                        }
                    }
                    .padding(6)
                }
                .onAppear {
                    if featureType == .dock {
                        PixelKit.fire(GeneralPixel.addToDockNewTabPageCardPresented,
                                      frequency: .uniqueByName,
                                      includeAppVersionParameter: false)
                    }
                }
            }
        }

        struct CardTemplate<Content: View>: View {

            var title: String
            var summary: String
            var actionText: String
            var confirmationText: String?
            @ViewBuilder var icon: Content
            let width: CGFloat
            let height: CGFloat
            let action: () -> Void

            @State var isHovering = false
            @State var isClicked = false
            @EnvironmentObject var settingsModel: HomePage.Models.SettingsModel

            var body: some View {
                ZStack(alignment: .center) {

                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.homeFavoritesGhost, style: StrokeStyle(lineWidth: 1.0))
                        .homePageViewBackground(settingsModel.customBackground)
                        .cornerRadius(12)

                    ZStack {
                        VStack(spacing: 18) {
                            icon
                                .frame(alignment: .center)
                            VStack(spacing: 4) {
                                Text(title)
                                    .bold()
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .font(.system(size: 13))
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(summary)
                                    .frame(width: 216, alignment: .center)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(.greyText))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                        .frame(width: 208, height: 130)
                        VStack {
                            Spacer()
                            if let confirmationText, isClicked {
                                HStack {
                                    Image(.successCheckmark)
                                    Text(confirmationText)
                                        .bold()
                                        .multilineTextAlignment(.center)
                                        .lineLimit(1)
                                        .font(.system(size: 11))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .offset(y: -3)
                            } else {
                                ActionButton(title: actionText,
                                             isHoveringOnCard: $isHovering,
                                             isClicked: $isClicked,
                                             action: action)
                            }
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
            let foregroundColorOnHover: Color = .homeFavoritesHover
            let foregroundColorOnHoverOnCard: Color = .homeFavoritesBackground
            private let titleWidth: Double

            @State var isHovering = false
            @Binding var isHoveringOnCard: Bool
            @Binding var isClicked: Bool

            init(title: String, isHoveringOnCard: Binding<Bool>, isClicked: Binding<Bool>, action: @escaping () -> Void) {
                self.title = title
                self.action = action
                self._isHoveringOnCard = isHoveringOnCard
                self._isClicked = isClicked
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
                        .foregroundColor(Color(.linkBlue))
                }
                .onTapGesture {
                    isClicked = true
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

        struct NextStepsView: View {
            let text = UserText.newTabSetUpSectionTitle
            let textWidth: CGFloat

            init() {
                textWidth = (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 14) as Any]).width
            }

            var body: some View {
                HStack(spacing: 0) {
                    Image(.nextStepsLeft)
                        .frame(width: 12, height: 5)
                        .padding(.top, 6)
                    ZStack {
                        Rectangle()
                            .fill(Color(.linkBlue))
                            .frame(width: textWidth, height: 20)
                        Text(text)
                            .foregroundColor(Color(.homeNextStepsText))
                    }
                    Image(.nextStepsRight)
                        .frame(width: 10, height: 19)
                }
            }
        }
    }
}

@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 600, height: 700)) {
    HomePage.Views.ContinueSetUpView()
        .environmentObject(HomePage.Models.SettingsModel())
        .environmentObject(HomePage.Models.ContinueSetUpModel(
            defaultBrowserProvider: SystemDefaultBrowserProvider(),
            dockCustomizer: DockCustomizer(),
            dataImportProvider: BookmarksAndPasswordsImportStatusProvider(),
            tabOpener: TabCollectionViewModelTabOpener(tabCollectionViewModel: TabCollectionViewModel()),
            duckPlayerPreferences: DuckPlayerPreferencesUserDefaultsPersistor()
        ))
}
