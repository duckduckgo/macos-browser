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
    let iconView: AnyView
    let text: String
    let animationDuration: CGFloat
    let animationSecondPhaseDelay: CGFloat
    
    @State var textOffset: CGFloat = -Consts.View.textScrollerOffset
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ExpandableRectangle()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                HStack {
                    Text(text)
                        .font(.footnote)
                        .offset(x: textOffset)
                        .onAppear {
                            withAnimation(.easeInOut(duration: animationDuration)) {
                                textOffset = 0
                            }
                            withAnimation(.easeInOut(duration: animationDuration).delay(animationSecondPhaseDelay)) {
                                textOffset = -Consts.View.textScrollerOffset
                            }
                        }
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
        }
    }
}

struct BadgeAnimationView_Previews: PreviewProvider {
    static var previews: some View {
        if #available(macOS 11.0, *) {
            BadgeAnimationView(iconView: AnyView(Image(systemName: "globle")),
                               text: "Test",
                               animationDuration: 3,
                               animationSecondPhaseDelay: 1)
            .frame(width: 100, height: 30)
        } else {
            Text("No Preview")
        }
    }
}

private enum Consts {
    enum View {
        static let cornerRadius: CGFloat = 8
        static let opaqueViewOffset: CGFloat = 10
        static let textScrollerOffset: CGFloat = 120
    }
    
    enum Colors {
        static let badgeBackgroundColor = Color("URLNotificationBadgeBackground")
    }
}
