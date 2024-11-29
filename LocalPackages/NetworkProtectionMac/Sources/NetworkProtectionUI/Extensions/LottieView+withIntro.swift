//
//  LottieView+withIntro.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import Lottie

extension LottieView where Placeholder: View {
    public struct LoopWithIntroTiming {
        let skipIntro: Bool
        let introStartFrame: AnimationFrameTime
        let introEndFrame: AnimationFrameTime
        let loopStartFrame: AnimationFrameTime
        let loopEndFrame: AnimationFrameTime
    }

    public func playing(withIntro timing: LoopWithIntroTiming, isAnimating: Bool = true) -> Lottie.LottieView<Placeholder> {
        configure { uiView in
            if uiView.isAnimationPlaying, !isAnimating {
                uiView.stop()
                return
            }

            guard isAnimating, !uiView.isAnimationPlaying else { return }

            if uiView.loopMode == .playOnce, uiView.currentProgress == 1 { return }

            if timing.skipIntro {
                uiView.play(fromFrame: timing.loopStartFrame, toFrame: timing.loopEndFrame, loopMode: .loop)
            } else {
                uiView.play(fromFrame: timing.introStartFrame, toFrame: timing.introEndFrame, loopMode: .playOnce) { _ in
                    uiView.play(fromFrame: timing.loopStartFrame, toFrame: timing.loopEndFrame, loopMode: .loop)
                }
            }
        }
    }
}
