//
//  BadgeAnimationView.swift
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

struct BadgeAnimationView: View {
    var animationModel: BadgeNotificationAnimationModel
    let iconView: AnyView
    let text: String
    @State var textOffset: CGFloat = -Consts.View.textScrollerOffset

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ExpandableRectangle(animationModel: animationModel)
                .frame(width: geometry.size.width, height: geometry.size.height)

                HStack {
                    Text(text)
                        .foregroundColor(.primary)
                        .font(.body)
                        .offset(x: textOffset)
                        .onReceive(animationModel.$state, perform: { state in
                            switch state {
                            case .expanded:
                                withAnimation(.easeInOut(duration: animationModel.duration)) {
                                    textOffset = 0
                                }
                            case .retracted:
                                withAnimation(.easeInOut(duration: animationModel.duration)) {
                                    textOffset = -Consts.View.textScrollerOffset
                                }
                            default:
                                break
                            }
                        })
                        .padding(.leading, geometry.size.height)

                    Spacer()
                }.clipped()

                // Opaque view
                HStack {
                    Rectangle()
                        .foregroundColor(Consts.Colors.badgeBackgroundColor)
                        .cornerRadius(Consts.View.cornerRadius)
                        .frame(width: geometry.size.height - Consts.View.opaqueViewOffset, height: geometry.size.height)
                    Spacer()
                }

                HStack {
                    iconView
                        .frame(width: geometry.size.height, height: geometry.size.height)
                    Spacer()
                }
            }
        }.frame(width: viewWidth)
    }

    private var viewWidth: CGFloat {
        let fontWidth = text.width(withFont: NSFont.preferredFont(forTextStyle: .body))

        let iconSize: CGFloat = 32
        let margins: CGFloat = 4

        return fontWidth + iconSize + margins
    }
}

struct ExpandableRectangle: View {
    @ObservedObject var animationModel: BadgeNotificationAnimationModel
    @State var width: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Consts.Colors.badgeBackgroundColor)
                .cornerRadius(Consts.View.cornerRadius)
                .frame(width: geometry.size.height + width, height: geometry.size.height)
                .onReceive(animationModel.$state, perform: { state in
                    switch state {
                    case .expanded:
                        withAnimation(.easeInOut(duration: animationModel.duration)) {
                            width = geometry.size.width - geometry.size.height
                        }

                    case .retracted:
                        withAnimation(.easeInOut(duration: animationModel.duration)) {
                                width = 0
                        }
                    default:
                        break
                    }
                })
        }
    }
}

struct BadgeAnimationView_Previews: PreviewProvider {
    static var previews: some View {
        BadgeAnimationView(animationModel: BadgeNotificationAnimationModel(),
                           iconView: AnyView(Image(systemName: "globe")),
                           text: "Test")
            .frame(width: 100, height: 30)
    }
}

private enum Consts {
    enum View {
        static let cornerRadius: CGFloat = 5
        static let opaqueViewOffset: CGFloat = 8
        static let textScrollerOffset: CGFloat = 120
    }

    enum Colors {
        static let badgeBackgroundColor = Color.urlNotificationBadgeBackground
    }
}

private extension String {
    func width(withFont font: NSFont) -> CGFloat {
        let fontAttributes = [NSAttributedString.Key.font: font]
        return self.size(withAttributes: fontAttributes).width
    }
}
