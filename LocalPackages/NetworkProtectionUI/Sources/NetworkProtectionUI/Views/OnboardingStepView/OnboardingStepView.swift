//
//  OnboardingStepView.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

struct OnboardingStepView: View {

    private let model: Model

    // MARK: - Initializers

    public init(model: Model) {
        self.model = model
    }

    // MARK: - View

    public var body: some View {
        VStack(spacing: 0) {

            HStack(alignment: .top, spacing: 0) {

                Image(model.icon)
                    .resizable() // Just a note that this is only necessary right now due to the asset being a really small placeholder.  This attribute should go away when we replace with the final assets.
                    .frame(width: 40, height: 40)
                    .padding(.trailing, 12)

                VStack(alignment: .leading, spacing: 0) {
                    Text(model.title)
                        .multilineText()

                    Text(model.description)
                        .multilineText()

                    Button(model.title, action: model.action)

                    Spacer()
                }
                .layoutPriority(1)

                Spacer()
            }
            .layoutPriority(1)
            .padding(.vertical, 16)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 0)

            Image(.allowSysexScreenshot)
                .resizable() // Just a note that this is only necessary right now due to the asset being a really small placeholder.  This attribute should go away when we replace with the final assets.
                .frame(width: 321, height: 130)

            Spacer()
        }
        .layoutPriority(1)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .circular)
                .stroke(Color.white.opacity(0.06))
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .circular)
                        .fill(Color.white.opacity(0.03))
                ))
    }
}
