//
//  RootView.swift
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

struct RootView: View {

    @EnvironmentObject var model: OnboardingViewModel
    @State var showOnboardingFlow = false
    @State var showBackgroundImage = false

    private static var onboardingFlowAnimation: Animation {
#if CI || DEBUG || REVIEW
        guard ProcessInfo().uiTestsEnvironment[.disableOnboardingAnimations]?.boolValue != true else {
            return .linear(duration: 0)
        }
#endif
        return .default
    }

    private static var backgroundImageAnimation: Animation {
#if CI || DEBUG || REVIEW
        guard ProcessInfo().uiTestsEnvironment[.disableOnboardingAnimations]?.boolValue != true else {
            return .linear(duration: 0)
        }
#endif
        return .easeIn.delay(0.3)
    }

    var body: some View {

        ZStack(alignment: .bottom) {

            Rectangle()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundColor(.white)
                .visibility(showBackgroundImage ? .invisible : .visible)

            OnboardingFlow()
                .visibility(showOnboardingFlow ? .visible : .gone)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {

            if model.state == .startBrowsing {
                showOnboardingFlow = true
                showBackgroundImage = true
                return
            }

            withAnimation(Self.onboardingFlowAnimation) {
                showOnboardingFlow = true
            }

            withAnimation(Self.backgroundImageAnimation) {
                showBackgroundImage = true
            }
        }

    }

}

}
