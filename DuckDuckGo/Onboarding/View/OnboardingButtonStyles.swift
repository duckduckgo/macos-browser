//
//  OnboardingButtonStyles.swift
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

struct ActionButtonStyle: ButtonStyle {

    func makeBody(configuration: Self.Configuration) -> some View {

        let color: Color = configuration.isPressed ? .onboardingActionButtonPressed : .onboardingActionButton

        configuration.label
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .truncationMode(.tail)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color))
            .foregroundColor(.white)
            .font(.system(size: 13, weight: .semibold, design: .default))

    }
}

struct SkipButtonStyle: ButtonStyle {

    func makeBody(configuration: Self.Configuration) -> some View {

        let color: Color = configuration.isPressed ? .onboardingSkipButtonPressed : .onboardingSkipButton

        configuration.label
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .truncationMode(.tail)
            .foregroundColor(.black)
            .font(.system(size: 13, weight: .semibold, design: .default))
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color)
                // background for the background to prevent transparency show matt anderson details
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(.onboardingSkipButtonBase))))

    }
}

}
