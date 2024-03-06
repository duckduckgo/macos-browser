//
//  OnboardingFlow.swift
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

struct OnboardingFlow: View {

    @EnvironmentObject var model: OnboardingViewModel

    @State var showLogo = false
    @State var showTitle = true
    @State var daxInSpeechPosition = false
    @State var showDialogs = false

    private static var logoAnimation: Animation {
#if CI || DEBUG || REVIEW
        guard ProcessInfo().uiTestsEnvironment[.disableOnboardingAnimations]?.boolValue != true else {
            return .linear(duration: 0)
        }
#endif
        return .easeIn(duration: 0.5)
    }

    private static var daxInSpeechAnimation: Animation {
#if CI || DEBUG || REVIEW
        guard ProcessInfo().uiTestsEnvironment[.disableOnboardingAnimations]?.boolValue != true else {
            return .linear(duration: 0)
        }
#endif
        return .easeIn
    }

    private static var onSplashFinishedAnimation: Animation {
#if CI || DEBUG || REVIEW
        guard ProcessInfo().uiTestsEnvironment[.disableOnboardingAnimations]?.boolValue != true else {
            return .linear(duration: 0)
        }
#endif
        return .default
    }

    private enum Constants {

        static var logoDelay: TimeInterval {
#if CI || DEBUG || REVIEW
            guard ProcessInfo().uiTestsEnvironment[.disableOnboardingAnimations]?.boolValue != true else { return 0 }
#endif
            return 1.5
        }

        static var daxInSpeechDelay: TimeInterval {
#if CI || DEBUG || REVIEW
            guard ProcessInfo().uiTestsEnvironment[.disableOnboardingAnimations]?.boolValue != true else { return 0 }
#endif
            return 3.0
        }

        static var onSplashFinishedDelay: TimeInterval {
#if CI || DEBUG || REVIEW
            guard ProcessInfo().uiTestsEnvironment[.disableOnboardingAnimations]?.boolValue != true else { return 0 }
#endif
            return 3.5
        }

    }

    var body: some View {

        VStack(alignment: daxInSpeechPosition ? .leading : .center) {

            HStack(alignment: .top, spacing: 23) {

                Image(.onboardingDax)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.16), radius: 6, x: 0, y: 3)
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                ZStack {
                    CallToAction(text: UserText.onboardingWelcomeText,
                                 cta: UserText.onboardingStartButton) {
                        model.onStartPressed()
                    }.visibility(model.state == .welcome ? .visible : .gone)

                    ActionSpeech(text: UserText.onboardingImportDataText,
                                 actionName: UserText.onboardingImportDataButton) {
                        model.onImportPressed()
                    } skip: {
                        model.onImportSkipped()
                    }.visibility(model.state == .importData ? .visible : .gone)

                    ActionSpeech(text: UserText.onboardingSetDefaultText,
                                 actionName: UserText.onboardingSetDefaultButton) {
                        model.onSetDefaultPressed()
                    } skip: {
                        model.onSetDefaultSkipped()
                    }.visibility(model.state == .setDefault ? .visible : .gone)

                    DaxSpeech(text: UserText.onboardingStartBrowsingText, onTypingFinished: nil)
                        .visibility(model.state == .startBrowsing ? .visible : .gone)

                }.visibility(showDialogs ? .visible : .gone)

                Spacer()
                    .visibility(daxInSpeechPosition ? .visible : .gone)

            }.visibility(showLogo ? .visible : .gone)

            Text(UserText.onboardingWelcomeTitle)
                .kerning(-1.26)
                .font(.system(size: 42, weight: .bold, design: .default))
                .foregroundColor(.black)
                .visibility(showTitle ? .visible : .gone)

            Spacer().visibility(daxInSpeechPosition ? .visible : .gone)

        }
        .padding(30)
        .onAppear {

            if model.state == .startBrowsing {
                showLogo = true
                daxInSpeechPosition = true
                showDialogs = true
                showTitle = false
                model.onboardingReshown()
                return
            }

            Timer.scheduledTimer(withTimeInterval: Constants.logoDelay, repeats: false) { _ in
                withAnimation(Self.logoAnimation) {
                    showLogo = true
                }
            }

            Timer.scheduledTimer(withTimeInterval: Constants.daxInSpeechDelay, repeats: false) { _ in
                withAnimation(Self.daxInSpeechAnimation) {
                    showTitle = false
                    daxInSpeechPosition = true
                }
            }

            Timer.scheduledTimer(withTimeInterval: Constants.onSplashFinishedDelay, repeats: false) { _ in
                withAnimation(Self.onSplashFinishedAnimation) {
                    model.onSplashFinished()
                    showDialogs = true
                }
            }

        }

    }

}

}
