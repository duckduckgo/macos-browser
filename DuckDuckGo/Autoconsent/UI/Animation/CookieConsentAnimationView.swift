//
//  CookieConsentAnimationView.swift
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

struct CookieConsentAnimationView<AnimationModel>: View where AnimationModel: CookieConsentAnimation {
    @ObservedObject var animationModel: AnimationModel

    var body: some View {
        VStack {
            HStack {
                withAnimation(.easeInOut(duration: animationModel.secondAnimationDuration)) {
                    Image("CookieConsentSketchMarks")
                        .foregroundColor(Color("CookieConsentSketchMarksColor"))
                        .opacity(animationModel.pillsOpacity)
                        .scaleEffect(animationModel.pillsScale)
                        .offset(x: animationModel.pillLeftSideOffset)
                }

                withAnimation(.easeInOut(duration: animationModel.firstAnimationDuration)) {
                    Image("CookieConsentSketch")
                        .opacity(animationModel.imageOpacity)
                        .scaleEffect(animationModel.imageScale)
                }

                withAnimation(.easeInOut(duration: animationModel.secondAnimationDuration)) {
                    Image("CookieConsentSketchMarks")
                        .foregroundColor(Color("CookieConsentSketchMarksColor"))
                        .rotationEffect(.degrees(180))
                        .opacity(animationModel.pillsOpacity)
                        .scaleEffect(animationModel.pillsScale)
                        .offset(x: animationModel.pillRightSideOffset)
                }
            }
        }
    }
}

struct CookieConsentAnimationView_Previews: PreviewProvider {
    static var previews: some View {
        CookieConsentAnimationView(animationModel: CookieConsentAnimationMock())
    }
}

final class CookieConsentAnimationMock: CookieConsentAnimation {
    var imageOpacity: CGFloat = 1
    var imageScale: CGFloat = 1
    var pillsOpacity: CGFloat = 1
    var pillsScale: CGFloat = 1
    var pillLeftSideOffset: CGFloat = 0
    var pillRightSideOffset: CGFloat = 0
    var firstAnimationDuration: CGFloat = 0.7
    var secondAnimationDuration: CGFloat = 0.5
    func startAnimation() { }
}
