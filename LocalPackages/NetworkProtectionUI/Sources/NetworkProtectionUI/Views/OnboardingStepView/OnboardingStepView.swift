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

private let defaultTextColor = Color("TextColor", bundle: .module)

fileprivate enum NetworkProtectionFont {
    static var connectionStatusDetail: Font {
        .system(size: 13, weight: .regular, design: .default)
    }

    static var content: Font {
        .system(size: 13, weight: .regular, design: .default)
    }

    static var description: Font {
        .system(size: 13, weight: .regular, design: .default)
    }

    static var menu: Font {
        .system(size: 13, weight: .regular, design: .default)
    }

    static var label: Font {
        .system(size: 13, weight: .regular, design: .default)
    }

    static var sectionHeader: Font {
        .system(size: 12, weight: .semibold, design: .default)
    }

    static var timer: Font {
        .system(size: 13, weight: .regular, design: .default)
        .monospacedDigit()
    }

    static var stepTitle: Font {
        .system(size: 13, weight: .bold, design: .default)
    }
}

private enum Opacity {
    static func connectionStatusDetail(colorScheme: ColorScheme) -> Double {
        colorScheme == .light ? Double(0.6) : Double(0.5)
    }

    static let content = Double(0.58)
    static let label = Double(0.9)
    static let description = Double(0.9)
    static let menu = Double(0.9)
    static let link = Double(1)

    static func sectionHeader(colorScheme: ColorScheme) -> Double {
        colorScheme == .light ? Double(0.84) : Double(0.85)
    }

    static func timer(colorScheme: ColorScheme) -> Double {
        colorScheme == .light ? Double(0.6) : Double(0.5)
    }

    static let stepTitle = Double(0.9)
}

fileprivate extension View {
    func applyConnectionStatusDetailAttributes(colorScheme: ColorScheme) -> some View {
        opacity(Opacity.connectionStatusDetail(colorScheme: colorScheme))
            .font(NetworkProtectionFont.connectionStatusDetail)
            .foregroundColor(defaultTextColor)
    }

    func applyContentAttributes(colorScheme: ColorScheme) -> some View {
        opacity(Opacity.content)
            .font(NetworkProtectionFont.content)
            .foregroundColor(defaultTextColor)
    }

    func applyDescriptionAttributes(colorScheme: ColorScheme) -> some View {
        opacity(Opacity.description)
            .font(NetworkProtectionFont.description)
            .foregroundColor(defaultTextColor)
    }

    func applyMenuAttributes() -> some View {
        opacity(Opacity.menu)
            .font(NetworkProtectionFont.menu)
            .foregroundColor(defaultTextColor)
    }

    func applyLinkAttributes(colorScheme: ColorScheme) -> some View {
        opacity(Opacity.link)
            .font(NetworkProtectionFont.content)
            .foregroundColor(defaultTextColor)
    }

    func applyLabelAttributes(colorScheme: ColorScheme) -> some View {
        opacity(Opacity.label)
            .font(NetworkProtectionFont.label)
            .foregroundColor(defaultTextColor)
    }

    func applySectionHeaderAttributes(colorScheme: ColorScheme) -> some View {
        opacity(Opacity.sectionHeader(colorScheme: colorScheme))
            .font(NetworkProtectionFont.sectionHeader)
            .foregroundColor(defaultTextColor)
    }

    func applyTimerAttributes(colorScheme: ColorScheme) -> some View {
        opacity(Opacity.timer(colorScheme: colorScheme))
            .font(NetworkProtectionFont.timer)
            .foregroundColor(defaultTextColor)
    }

    func applyStepTitleAttributes(colorScheme: ColorScheme) -> some View {
        self.font(Font.custom("SF Pro Text", size: 13).weight(.bold))
            .foregroundColor(.black)
    }
}

struct OnboardingStepView: View {
    @Environment(\.colorScheme) var colorScheme

    // MARK: - Model

    private let model: Model

    // MARK: - Initializers

    public init(model: Model) {
        self.model = model
    }

    // MARK: - View

    struct Constants {
        static let IconsMenuMac: Color = .black.opacity(0.9)
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(model.icon)

                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.title)
                            .applyStepTitleAttributes(colorScheme: colorScheme)
                            .multilineText()

                        model.description.reduce(Text("")) { previous, fragment in
                            var newText = Text(fragment.text)

                            if fragment.isBold {
                                newText = newText.bold()
                            }

                            return previous + newText
                        }
                        .font(Font.custom("SF Pro Text", size: 13))
                        .foregroundColor(.black)
                        .multilineText()

                        Button(model.actionTitle, action: model.action)
                            .buttonStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 0)
                            .frame(height: 20, alignment: .center)
                            .background(Color.white)
                            .cornerRadius(5)
                            .shadow(color: .black.opacity(0.1), radius: 0.5, x: 0, y: 1)
                            .shadow(color: .black.opacity(0.05), radius: 0.5, x: 0, y: 0)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .inset(by: -0.25)
                                    .stroke(.black.opacity(0.1), lineWidth: 0.5)
                            )
                    }

                    Spacer()
                }
            }
            .padding(.top, 16)
            .padding(.bottom, model.actionScreenshot != nil ? 4 : 16)
            .padding(.horizontal, 10)

            if let actionScreenshot = model.actionScreenshot {
                Image(actionScreenshot)
                    .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 0)
            }
        }
        .cornerRadius(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .circular)
                .stroke(Color(.onboardingStepBorder))
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .circular)
                        .fill(Color(.onboardingStepBackground))
                ))
    }
}
