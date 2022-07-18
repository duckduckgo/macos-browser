//
//  CookieBlockedNotificationView.swift
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

private enum Consts {
    enum CookieAnimation {
        static let duration = 1.5
        static let halfDuration = duration / 2
        static let secondPhaseDelay = halfDuration
    }
    
    enum BadgeAnimation {
        static let duration = 1.0
        static let halfDuration = duration / 2
        static let secondPhaseDelay = 3.0
    }
    
    enum Layout {
        static let cookieSize: CGFloat = 32
        static let dotsGroupSize: CGFloat = 50
        static let randomDegreesOffset = 40
    }
    
    enum Count {
        static let circle = 5
    }
}

struct ContentView: View {
    var body: some View {
        HStack {
            CookieBadgeAnimationView()
                .border(Color.white,width: 2)
                Spacer()
        }.padding()
            .frame(width: 250, height: 100)
            .background(Color.yellow)
    }
}

struct CookieBadgeAnimationView: View {
    @State var width: CGFloat = 70
    @State var textOffset: CGFloat = -100
    
    var body: some View {
        ZStack {
            Rectangle()
                .cornerRadius(8)
                .foregroundColor(.red)
            
            Text("Cookies Managed")
                .offset(x: textOffset)
            HStack {
                CookieAnimationView()
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .onAppear {
            withAnimation(.easeInOut(duration: Consts.BadgeAnimation.duration)) {
                textOffset = 0
            }
            withAnimation(.easeInOut(duration: Consts.BadgeAnimation.duration).delay(Consts.BadgeAnimation.secondPhaseDelay)) {
                width = 70
            }
        }
    }
}


struct CookieAnimationView: View {
    @State var cookieAlpha: CGFloat = 1
    @State var bittenCookieAlpha: CGFloat = 0
    
    var body: some View {
        ZStack(alignment: .center) {
            Group {
                Image("Cookie")
                    .resizable()
                    .opacity(cookieAlpha)
                
                Image("CookieBite")

                    .resizable()
                    .opacity(bittenCookieAlpha)
                
                InnerExpandingCircle()
                OutterExpandingCircle()
            }
            .frame(width: Consts.Layout.cookieSize,
                   height: Consts.Layout.cookieSize)
            
            DotGroupView(circleCount: Consts.Count.circle)
                .frame(width: Consts.Layout.dotsGroupSize,
                       height: Consts.Layout.dotsGroupSize)
            
        }
        .border(Color.black, width: 2)
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
            .strokeBorder(.blue, lineWidth: 2)
            .opacity(opacity)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: Consts.CookieAnimation.halfDuration)) {
                    opacity = 1
                    scale = 1.2
                }
                
                withAnimation(.easeInOut(duration: Consts.CookieAnimation.halfDuration).delay(Consts.CookieAnimation.secondPhaseDelay)) {
                    opacity = 0
                    scale = 1.8
                }
            }
    }
}

struct OutterExpandingCircle: View {
    @State var opacity: CGFloat = 0
    @State var scale: CGFloat = 1.5
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
                    scale = 2.2
                }
            }
    }
}


struct DotView: View {
    let size: CGFloat = 10
    let geo: GeometryProxy
    let index: Int
    @State var scale: CGFloat = 1
    @State var opacity: CGFloat = 0
    @State var isContracted = true
    @State var expandedOffset: CGFloat = 0
    
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
                    scale = 0
                    opacity = 0
                    expandedOffset = -10
                }
            }
    }
    
    private func xPositionWithGeometry(_ proxy: GeometryProxy, isContracted: Bool) -> CGFloat {
        //let expandedXOffset: CGFloat = 0
        return isContracted ? proxy.size.width/2 : size/2 + expandedOffset
    }
    
    private func yPositionWithGeometry(_ proxy: GeometryProxy, isContracted: Bool) -> CGFloat {
        return isContracted ? proxy.size.height/2 : size/2  + expandedOffset
    }
}

extension Animation {
    static let expandDots = Animation.easeInOut(duration: 2.4)
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
        
    }
}
