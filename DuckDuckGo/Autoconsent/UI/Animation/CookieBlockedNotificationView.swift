//
//  ContentView.swift
//  CookieAnimation
//
//  Created by Fernando Bunn on 18/07/2022.
//

import SwiftUI

private enum Consts {
    enum CookieAnimation {
        static let duration: CGFloat = 5.0 //1.5
        static let halfDuration = duration / 2
        static let secondPhaseDelay = halfDuration
        
        static let innerExpandingCircleScale1 = 1.2
        static let innerExpandingCircleScale2 = 1.8
        
        static let outerExpandingCircleScale1 = 1.5
        static let outerExpandingCircleScale2 = 2.2
    }
    
    enum BadgeAnimation {
        static let duration: CGFloat = 5.0
        static let halfDuration = duration / 2
        static let secondPhaseDelay = 3.0
    }
    
    enum Layout {
        static let cookieSize: CGFloat = 24
        static let dotsGroupSize: CGFloat = 35
        static let randomDegreesOffset = 40
        static let dotSize: CGFloat = 7
    }
    
    enum Count {
        static let circle = 5
    }
}

struct ContentView: View {
    var body: some View {
        HStack {
            BadgeAnimationView(iconView: AnyView(CookieAnimationView()),
                               text: "Cookies Managed")
            Spacer()
        }.padding()
            .frame(width: 250, height: 100)
            .background(Color.yellow)
    }
}

struct BadgeAnimationView: View {
    let iconView: AnyView
    let text: String
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ExpandableRectangle()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                HStack{
                    iconView
                        .frame(width: geometry.size.height, height: geometry.size.height)
                    Spacer()
                }
                .border(Color.red, width: 1)
            }
        }
        .border(Color.white, width: 1)
    }
}

struct ExpandableRectangle: View {
    @State var width: CGFloat = 0
    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(.brown)
                .cornerRadius(8)
                .frame(width: geometry.size.height + width, height: geometry.size.height)
                .onAppear {
                    withAnimation(.easeInOut(duration: 3)) {
                        width = geometry.size.width - geometry.size.height
                    }
                }
        }
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
                    .background(Color.red)
                    .border(Color.white, width: 2)
                Spacer()
            }
        }
        //   .frame(maxWidth: .infinity)
        // .frame(height: 60)
        //        .onAppear {
        //            withAnimation(.easeInOut(duration: Consts.BadgeAnimation.duration)) {
        //                textOffset = 0
        //            }
        //            withAnimation(.easeInOut(duration: Consts.BadgeAnimation.duration).delay(Consts.BadgeAnimation.secondPhaseDelay)) {
        //                width = 70
        //            }
        //        }
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
                        .opacity(cookieAlpha)
                    
                    Image("CookieBite")
                    
                        .resizable()
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
            .strokeBorder(.blue, lineWidth: 2)
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
                    expandedOffset = -6
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
