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
    var isCosmetic: Bool

    @ObservedObject var animationModel: CookieNotificationAnimationModel
    var badgeAnimationModel: BadgeNotificationAnimationModel

    var body: some View {
        BadgeAnimationView(animationModel: badgeAnimationModel,
                           iconView: AnyView(CookieAnimationView(animationModel: animationModel)),
                           text: isCosmetic ? UserText.cookiePopupHiddenNotification : UserText.cookiePopupManagedNotification)
    }
}

struct CookieAnimationView: View {
    @ObservedObject var animationModel: CookieNotificationAnimationModel

    @State private var cookieAlpha: CGFloat = 1
    @State private var bittenCookieAlpha: CGFloat = 0

    var body: some View {
        Group {
            ZStack(alignment: .center) {
                Group {
                    Image(.cookie)
                        .resizable()
                        .foregroundColor(.primary)
                        .opacity(cookieAlpha)

                      Image(.cookieBite)
                        .resizable()
                        .foregroundColor(.primary)
                        .opacity(bittenCookieAlpha)

                    InnerExpandingCircle(animationModel: animationModel)
                    OuterExpandingCircle(animationModel: animationModel)
                }
                .frame(width: Consts.Layout.cookieSize,
                       height: Consts.Layout.cookieSize)

                DotGroupView(animationModel: animationModel,
                             circleCount: Consts.Count.circle)
                    .frame(width: Consts.Layout.dotsGroupSize,
                           height: Consts.Layout.dotsGroupSize)

            }
        }.frame(width: Consts.Layout.dotsGroupSize * 1.6,
                height: Consts.Layout.dotsGroupSize * 1.6)
        .onReceive(animationModel.$state, perform: { state in
            switch state {
            case .firstPhase:
                withAnimation(.easeInOut(duration: animationModel.duration)) {
                    cookieAlpha = 0
                    bittenCookieAlpha = 1
                }
            default:
                break
            }
        })
    }
}

private struct DotGroupView: View {
    var animationModel: CookieNotificationAnimationModel
    let circleCount: Int

    private func degreesOffset(for index: Int) -> Double {
        return Double(((360 / circleCount) * index) + Int.random(in: 0..<Consts.Layout.randomDegreesOffset))
    }

    var body: some View {
        Group {
            GeometryReader { geo in

                ForEach(0..<self.circleCount, id: \.self) { i in
                    ZStack {
                        DotView(animationModel: animationModel,
                                geo: geo,
                                index: i)
                    }
                    .rotationEffect(.degrees(degreesOffset(for: i)))
                }
            }
        }
    }
}

private struct InnerExpandingCircle: View {
    @ObservedObject var animationModel: CookieNotificationAnimationModel
    @State private var opacity: CGFloat = 0
    @State private var scale: CGFloat = Consts.CookieAnimation.innerExpandingCircleScale1
    var body: some View {
        Circle()
            .strokeBorder(.blue, lineWidth: 1)
            .opacity(opacity)
            .scaleEffect(scale)
            .onReceive(animationModel.$state, perform: { state in
                switch state {
                case .firstPhase:
                    withAnimation(.easeInOut(duration: animationModel.duration)) {
                        opacity = 1
                        scale = Consts.CookieAnimation.innerExpandingCircleScale2
                    }
                case .secondPhase:
                    withAnimation(.easeInOut(duration: animationModel.halfDuration)) {
                        opacity = 0
                    }
                default:
                    break
                }
            })
    }
}

private struct OuterExpandingCircle: View {
    @ObservedObject var animationModel: CookieNotificationAnimationModel
    @State private var opacity: CGFloat = 0
    @State private var scale: CGFloat = Consts.CookieAnimation.outerExpandingCircleScale1
    var body: some View {
        Circle()
            .strokeBorder(.blue, lineWidth: 1)
            .opacity(opacity)
            .scaleEffect(scale)
            .onReceive(animationModel.$state, perform: { state in
                switch state {
                case .firstPhase:
                    withAnimation(.easeInOut(duration: animationModel.duration)) {
                        opacity = 1
                        scale = Consts.CookieAnimation.outerExpandingCircleScale2
                    }
                case .secondPhase:
                    withAnimation(.easeInOut(duration: animationModel.halfDuration)) {
                        opacity = 0
                    }
                default:
                    break
                }
            })
    }
}

private struct DotView: View {
    @ObservedObject var animationModel: CookieNotificationAnimationModel
    let size = Consts.Layout.dotSize
    let geo: GeometryProxy
    let index: Int
    @State private var scale: CGFloat = 1
    @State private var opacity: CGFloat = 0
    @State private var isContracted = true
    @State private var expandedOffset: CGFloat = -1

    var body: some View {
        Circle()
            .fill(Color.blue)
            .opacity(opacity)
            .scaleEffect(scale)
            .frame(width: size, height: size)
            .position(x: xPositionWithGeometry(geo, isContracted: isContracted),
                      y: yPositionWithGeometry(geo, isContracted: isContracted))
            .onReceive(animationModel.$state, perform: { state in
                switch state {
                case .firstPhase:
                    withAnimation(.easeInOut(duration: animationModel.halfDuration)) {
                        self.isContracted.toggle()
                        opacity = 1
                    }
                case .secondPhase:
                    withAnimation(.easeInOut(duration: animationModel.halfDuration)) {
                        // Fix: ignoring singular matrix
                        scale = 0.001
                        opacity = 0
                        expandedOffset = -3
                    }
                default:
                    break
                }
            })
    }

    private func xPositionWithGeometry(_ proxy: GeometryProxy, isContracted: Bool) -> CGFloat {
        return isContracted ? proxy.size.width/2 : size/2 + expandedOffset
    }

    private func yPositionWithGeometry(_ proxy: GeometryProxy, isContracted: Bool) -> CGFloat {
        return isContracted ? proxy.size.height/2 : size/2  + expandedOffset
    }
}

struct CookieManagedNotificationView_Previews: PreviewProvider {
    static var previews: some View {
        CookieManagedNotificationView(isCosmetic: false,
                                      animationModel: CookieNotificationAnimationModel(),
                                      badgeAnimationModel: BadgeNotificationAnimationModel())
            .frame(width: 148, height: 32)
    }
}

private enum Consts {

    enum Colors {
        static let badgeBackgroundColor = Color.urlNotificationBadgeBackground
    }

    enum CookieAnimation {
        static let innerExpandingCircleScale1 = 1.0
        static let innerExpandingCircleScale2 = 1.4

        static let outerExpandingCircleScale1 = 1.2
        static let outerExpandingCircleScale2 = 1.8
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
