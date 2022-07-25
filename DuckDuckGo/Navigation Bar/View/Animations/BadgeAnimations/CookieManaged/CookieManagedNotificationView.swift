//
//  CookieManagedNotificationView.swift
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

struct CookieManagedNotificationView: View {
    var body: some View {
        BadgeAnimationView(iconView: AnyView(CookieAnimationView()),
                           text: UserText.cookiesManagedNotification,
                           animationDuration: Consts.BadgeAnimation.duration,
                           animationSecondPhaseDelay: Consts.BadgeAnimation.secondPhaseDelay)
    }
}

struct ExpandableRectangle: View {
    @State var width: CGFloat = 0
    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Consts.Colors.badgeBackgroundColor)
                .cornerRadius(Consts.Layout.cornerRadius)
                .frame(width: geometry.size.height + width, height: geometry.size.height)
                .onAppear {
                    withAnimation(.easeInOut(duration: Consts.BadgeAnimation.duration)) {
                        width = geometry.size.width - geometry.size.height
                    }
                    
                    withAnimation(.easeInOut(duration: Consts.BadgeAnimation.duration).delay(Consts.BadgeAnimation.secondPhaseDelay)) {
                            width = 0
                    }
                }
        }
    }
}

struct CookieAnimationView: View {
    @State var cookieAlpha: CGFloat = 1
    @State var bittenCookieAlpha: CGFloat = 0
    
    var body: some View {
        Group {
            ZStack(alignment: .center) {
                Group {
                    Image("Cookie")
                        .resizable()
                        .foregroundColor(.primary)
                        .opacity(cookieAlpha)
                    
                    Image("CookieBite")
                        .resizable()
                        .foregroundColor(.primary)
                        .opacity(bittenCookieAlpha)
                    
                    InnerExpandingCircle()
                    OuterExpandingCircle()
                }
                .frame(width: Consts.Layout.cookieSize,
                       height: Consts.Layout.cookieSize)
                
                DotGroupView(circleCount: Consts.Count.circle)
                    .frame(width: Consts.Layout.dotsGroupSize,
                           height: Consts.Layout.dotsGroupSize)
                
            }
        }.frame(width: Consts.Layout.dotsGroupSize * 1.6,
                height: Consts.Layout.dotsGroupSize * 1.6)
        .onAppear {
            withAnimation(.easeInOut(duration: Consts.CookieAnimation.duration)) {
                cookieAlpha = 0
                bittenCookieAlpha = 1
            }
        }
    }
    
    func startAnimation() {
        withAnimation(.easeInOut(duration: Consts.CookieAnimation.duration)) {
            cookieAlpha = 0
            bittenCookieAlpha = 1
        }
    }
}

struct DotGroupView: View {
    let circleCount: Int
    
    private func degreesOffset(for index: Int) -> Double {
        return Double(((360 / circleCount) * index) + Int.random(in: 0..<Consts.Layout.randomDegreesOffset))
    }
    
    var body: some View {
        Group {
            GeometryReader { geo in
                
                ForEach(0..<self.circleCount, id: \.self) { i in
                    ZStack {
                        DotView(geo: geo, index: i)
                    }
                    .rotationEffect(.degrees(degreesOffset(for: i)))
                }
            }
        }
    }
}

struct InnerExpandingCircle: View {
    @State var opacity: CGFloat = 0
    @State var scale: CGFloat = 1
    var body: some View {
        Circle()
            .strokeBorder(.blue, lineWidth: 1)
            .opacity(opacity)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: Consts.CookieAnimation.halfDuration)) {
                    opacity = 1
                    scale = Consts.CookieAnimation.innerExpandingCircleScale1
                }
                
                withAnimation(.easeInOut(duration: Consts.CookieAnimation.halfDuration).delay(Consts.CookieAnimation.secondPhaseDelay)) {
                    opacity = 0
                    scale = Consts.CookieAnimation.innerExpandingCircleScale2
                }
            }
    }
}

struct OuterExpandingCircle: View {
    @State var opacity: CGFloat = 0
    @State var scale: CGFloat = Consts.CookieAnimation.outerExpandingCircleScale1
    var body: some View {
        Circle()
            .strokeBorder(.blue, lineWidth: 1)
            .opacity(opacity)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: Consts.CookieAnimation.halfDuration)) {
                    opacity = 1
                }
                
                withAnimation(.easeInOut(duration: Consts.CookieAnimation.halfDuration).delay(Consts.CookieAnimation.secondPhaseDelay)) {
                    opacity = 0
                    scale = Consts.CookieAnimation.outerExpandingCircleScale2
                }
            }
    }
}

struct DotView: View {
    let size = Consts.Layout.dotSize
    let geo: GeometryProxy
    let index: Int
    @State var scale: CGFloat = 1
    @State var opacity: CGFloat = 0
    @State var isContracted = true
    @State var expandedOffset: CGFloat = -1
    
    var body: some View {
        Circle()
            .fill(Color.blue)
            .opacity(opacity)
            .scaleEffect(scale)
            .frame(width: size, height: size)
            .position(x: xPositionWithGeometry(geo, isContracted: isContracted),
                      y: yPositionWithGeometry(geo, isContracted: isContracted))
            .onAppear {
                withAnimation(.easeInOut(duration: Consts.CookieAnimation.halfDuration)) {
                    self.isContracted.toggle()
                    opacity = 1
                }
                withAnimation(.easeInOut(duration: Consts.CookieAnimation.halfDuration).delay(Consts.CookieAnimation.secondPhaseDelay)) {
                    // Fix: ignoring singular matrix
                    scale = 0.001
                    opacity = 0
                    expandedOffset = -2
                }
            }
    }
    
    private func xPositionWithGeometry(_ proxy: GeometryProxy, isContracted: Bool) -> CGFloat {
        return isContracted ? proxy.size.width/2 : size/2 + expandedOffset
    }
    
    private func yPositionWithGeometry(_ proxy: GeometryProxy, isContracted: Bool) -> CGFloat {
        return isContracted ? proxy.size.height/2 : size/2  + expandedOffset
    }
}

extension Animation {
    static let expandDots = Animation.easeInOut(duration: 2.4)
}

struct CookieManagedNotificationView_Previews: PreviewProvider {
    static var previews: some View {
        CookieManagedNotificationView()
            .frame(width: 148, height: 32)
    }
}

private enum Consts {
    
    enum Colors {
        static let badgeBackgroundColor = Color("URLNotificationBadgeBackground")
    }
    
    enum CookieAnimation {
        static let duration: CGFloat = 1.5
        static let halfDuration = duration / 2
        static let secondPhaseDelay = halfDuration
        
        static let innerExpandingCircleScale1 = 1.2
        static let innerExpandingCircleScale2 = 1.6
        
        static let outerExpandingCircleScale1 = 1.5
        static let outerExpandingCircleScale2 = 2.0
    }
    
    enum BadgeAnimation {
        static let duration: CGFloat = 0.8
        static let secondPhaseDelay = 3.0
    }

    enum Layout {
        static let cookieSize: CGFloat = 16
        static let dotsGroupSize: CGFloat = 18
        static let randomDegreesOffset = 40
        static let dotSize: CGFloat = 3
        static let cornerRadius: CGFloat = 5
    }
    
    enum Count {
        static let circle = 5
    }
}
