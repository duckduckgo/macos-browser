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

    enum OnboardingPhase {

        case start
        case welcome
        case importData
        case setDefault
        case startBrowsing

    }

    weak var delegate: OnboardingDelegate?

    @State var makeSpace = false
    @State var showLogo = false
    @State var showTitle = true
    @State var showSpeech = false
    @State var phase: OnboardingPhase = .start

    func moveToPhase(_ phase: OnboardingPhase) {
        withAnimation {
            self.phase = phase
        }
    }

    var body: some View {

        VStack(alignment: showSpeech ? .leading : .center) {

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

                CallToActionView(text: UserText.onboardingWelcomeText,
                                 cta: UserText.onboardingStartButton,
                                 pixel: .onboardingStartPressed) {
                    moveToPhase(.importData)
                }
                .visibility(showSpeech && phase == .welcome ? .visible : .gone)

                ActionSpeech(text: UserText.onboardingImportDataText,
                             actionName: UserText.onboardingImportDataButton,
                             actionPixel: .onboardingImportPressed,
                             skipPixel: .onboardingImportSkipped) {
                    delegate?.onboardingDidRequestImportData {
                        moveToPhase(.setDefault)
                    }
                } skip: {
                    moveToPhase(.setDefault)
                }
                .visibility(showSpeech && phase == .importData ? .visible : .gone)

                ActionSpeech(text: UserText.onboardingSetDefaultText,
                             actionName: UserText.onboardingSetDefaultButton,
                             actionPixel: .onboardingSetDefaultPressed,
                             skipPixel: .onboardingSetDefaultSkipped) {
                    delegate?.onboardingDidRequestSetDefault {
                        moveToPhase(.startBrowsing)
                    }
                } skip: {
                    moveToPhase(.startBrowsing)
                }
                .visibility(showSpeech && phase == .setDefault ? .visible : .gone)

                DaxSpeech(text: UserText.onboardingStartBrowsingText)
                .onAppear {
                    delegate?.onboardingHasFinished()
                }
                .visibility(showSpeech && phase == .startBrowsing ? .visible : .gone)

                Spacer()
                    .visibility(showSpeech ? .visible : .gone)

            }.visibility(showLogo ? .visible : .gone)

            Spacer().visibility(showSpeech ? .visible : .gone)

        }
        .padding()
        .onAppear {

            withAnimation(.easeIn(duration: 0.5).delay(1.5)) {
                makeSpace = true
            }

            withAnimation(.easeIn(duration: 0.5).delay(2.0)) {
                showLogo = true
                makeSpace = false
            }

            withAnimation(.easeIn.delay(3.0)) {
                showTitle = false
                showSpeech = true
            }

            withAnimation(.easeIn.delay(3.5)) {
                phase = .welcome
            }

        }

    }

}

}
