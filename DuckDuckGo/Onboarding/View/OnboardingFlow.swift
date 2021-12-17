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

extension Onboarding {

struct OnboardingFlow: View {

    @EnvironmentObject var model: OnboardingViewModel

    @State var makeSpace = false
    @State var showLogo = false
    @State var showTitle = true
    @State var daxInSpeechPosition = false
    @State var showDialogs = false

    // Not used for display, just needs to be passed to DaxSpeech. Might be a better way to do this.
    @State var typingFinished = false

    var body: some View {

        VStack(alignment: daxInSpeechPosition ? .leading : .center) {

            Text(UserText.onboardingWelcomeTitle)
                .kerning(-1.26)
                .font(.system(size: 42, weight: .bold, design: .default))
                .foregroundColor(.black)
                .visibility(showTitle ? .visible : .gone)

            Color.clear.frame(width: 64, height: 64)
                .visibility(makeSpace ? .visible : .gone)

            HStack(alignment: .top) {

                Image("OnboardingDax")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.16), radius: 6, x: 0, y: 3)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.init(top: 0, leading: 0, bottom: 0, trailing: daxInSpeechPosition ? 10 : 0))

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

            Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                withAnimation(.easeIn(duration: 0.5)) {
                    makeSpace = true
                }
            }

            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                withAnimation(.easeIn(duration: 0.5)) {
                    showLogo = true
                    makeSpace = false
                }
            }

            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                withAnimation(.easeIn) {
                    showTitle = false
                    daxInSpeechPosition = true
                }
            }

            Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { _ in
                withAnimation {
                    model.onSplashFinished()
                    showDialogs = true
                }
            }

        }

    }

}

}
