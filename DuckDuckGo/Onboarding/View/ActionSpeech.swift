//
//  ActionSpeech.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

extension Onboarding {

struct ActionSpeech: View {

    let text: String
    let actionName: String
    let action: () -> Void
    let skip: () -> Void

    @State var typingFinished = false

    private static var animation: Animation {
#if CI || DEBUG || REVIEW
        guard ProcessInfo().uiTestsEnvironment[.disableOnboardingAnimations]?.boolValue != true else {
            return .linear(duration: 0)
        }
#endif
        return .default
    }

    var body: some View {
        VStack(spacing: 15) {
            DaxSpeech(text: text) {
                withAnimation(Self.animation) {
                    typingFinished = true
                }
            }

            HStack(spacing: 12) {

                Button(UserText.onboardingNotNowButton) {
                    withAnimation(Self.animation) {
                        skip()
                    }
                }
                .buttonStyle(SkipButtonStyle())

                Button(actionName) {
                    withAnimation(Self.animation) {
                        action()
                    }
                }
                .buttonStyle(ActionButtonStyle())

            }
            .visibility(typingFinished ? .visible : .gone)
            .frame(width: speechWidth)

        }
    }

}

}
