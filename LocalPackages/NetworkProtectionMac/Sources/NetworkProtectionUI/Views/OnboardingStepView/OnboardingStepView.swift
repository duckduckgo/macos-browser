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

fileprivate extension View {
    func applyStepTitleAttributes() -> some View {
        self.font(.system(size: 13).weight(.bold))
            .foregroundColor(Color(.defaultText))
    }

    func applyStepDescriptionAttributes() -> some View {
        self.font(.system(size: 13))
            .foregroundColor(Color(.defaultText))
    }

    @ViewBuilder
    func applyStepButtonAttributes(colorScheme: ColorScheme) -> some View {
        switch colorScheme {
        case .dark:
            self.buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 0)
                .frame(height: 20, alignment: .center)
                .background(Color(.onboardingButtonBackgroundColor))
                .cornerRadius(5)
                .shadow(color: .black.opacity(0.2), radius: 0.5, x: 0, y: 1)
                .shadow(color: .black.opacity(0.05), radius: 0.5, x: 0, y: 0)
                .shadow(color: .black.opacity(0.1), radius: 0, x: 0, y: 0)
        default:
            self.buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 0)
                .frame(height: 20, alignment: .center)
                .background(Color(.onboardingButtonBackgroundColor))
                .cornerRadius(5)
                .shadow(color: .black.opacity(0.1), radius: 0.5, x: 0, y: 1)
                .shadow(color: .black.opacity(0.05), radius: 0.5, x: 0, y: 0)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .inset(by: -0.25)
                        .stroke(.black.opacity(0.1), lineWidth: 0.5)
                )
        }
    }
}

struct OnboardingStepView: View {

    @Environment(\.colorScheme) var colorScheme

    // MARK: - Model

    private let icon: NetworkProtectionAsset
    private let title: String
    private let description: [Model.StyledTextFragment]
    private let actionTitle: String
    private let action: () -> Void
    private let actionScreenshot: NetworkProtectionAsset?

    // MARK: - Initializers

    public init(model: Model) {
        self.init(
            icon: model.icon,
            title: model.title,
            description: model.description,
            actionTitle: model.actionTitle,
            action: model.action,
            actionScreenshot: model.actionScreenshot
        )
    }

    public init(icon: NetworkProtectionAsset,
                title: String,
                description: [Model.StyledTextFragment],
                actionTitle: String,
                action: @escaping () -> Void,
                actionScreenshot: NetworkProtectionAsset?) {
        self.icon = icon
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.action = action
        self.actionScreenshot = actionScreenshot
    }

    // MARK: - View

    public var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(icon)

                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .applyStepTitleAttributes()
                            .multilineText()

                        description.reduce(Text("")) { previous, fragment in
                            var newText = Text(fragment.text)

                            if fragment.isEmphasized {
                                newText = newText.fontWeight(.semibold)
                            }

                            return previous + newText
                        }
                        .applyStepDescriptionAttributes()
                        .multilineText()

                        Button(actionTitle, action: action)
                            .applyStepButtonAttributes(colorScheme: colorScheme)
                            .padding(.top, 3)
                    }

                    Spacer()
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 10)

            if let actionScreenshot = self.actionScreenshot {
                Image(actionScreenshot)
            }
        }
        .cornerRadius(8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .circular)
                .stroke(Color(.onboardingStepBorder), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .circular)
                        .fill(Color(.onboardingStepBackground))
                ))
    }
}
