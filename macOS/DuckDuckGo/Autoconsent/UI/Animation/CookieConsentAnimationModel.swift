//
//  CookieConsentAnimationModel.swift
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

import Foundation
import SwiftUI

protocol CookieConsentAnimation: ObservableObject {
    var imageOpacity: CGFloat { get set}
    var imageScale: CGFloat { get set}
    var pillsOpacity: CGFloat { get set}
    var pillsScale: CGFloat { get set}
    var pillLeftSideOffset: CGFloat { get set}
    var pillRightSideOffset: CGFloat { get set}
    var firstAnimationDuration: CGFloat { get }
    var secondAnimationDuration: CGFloat { get }

    func startAnimation()
}

final class CookieConsentAnimationModel: CookieConsentAnimation {

    private enum Animation {
        struct AnimationValue {
            let begin: CGFloat
            let end: CGFloat
        }

        enum Image {
            static let opacity = AnimationValue(begin: 0, end: 1)
            static let scale = AnimationValue(begin: 0, end: 1)
        }

        enum Pills {
            static let opacity = AnimationValue(begin: 0, end: 1)
            static let scale = AnimationValue(begin: 0, end: 1)
            static let leftSideOffset = AnimationValue(begin: 30, end: 0)
            static let rightSideOffset = AnimationValue(begin: -30, end: 0)
        }
    }

    let firstAnimationDuration: CGFloat = 0.35
    let secondAnimationDuration: CGFloat = 0.3

    @Published var imageOpacity = Animation.Image.opacity.begin
    @Published var imageScale = Animation.Image.scale.begin
    @Published var pillsOpacity = Animation.Pills.opacity.begin
    @Published var pillsScale = Animation.Pills.scale.begin
    @Published var pillLeftSideOffset = Animation.Pills.leftSideOffset.begin
    @Published var pillRightSideOffset = Animation.Pills.rightSideOffset.begin

    private func updateDataForFirstAnimation() {
        withAnimation(.easeInOut(duration: firstAnimationDuration)) {
            imageOpacity = Animation.Image.opacity.end
            imageScale = Animation.Image.scale.end
        }
    }

    private func updateDataForSecondAnimation() {
        withAnimation(.easeInOut(duration: secondAnimationDuration)) {
            pillsOpacity = Animation.Pills.opacity.end
            pillsScale = Animation.Pills.scale.end
            pillRightSideOffset = Animation.Pills.rightSideOffset.end
            pillLeftSideOffset = Animation.Pills.leftSideOffset.end
        }
    }

    func startAnimation() {
        updateDataForFirstAnimation()

        DispatchQueue.main.asyncAfter(deadline: .now() + (firstAnimationDuration) / 2) {
            self.updateDataForSecondAnimation()
        }
    }
}
