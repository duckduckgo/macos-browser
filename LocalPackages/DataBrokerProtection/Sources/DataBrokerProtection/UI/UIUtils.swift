//
//  CTAButtonStyle.swift
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

import SwiftUI

struct CTAButtonStyle: ButtonStyle {
    enum Style {
        case primary
        case secundary
    }

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.isEnabled) private var isEnabled: Bool

    let style: Style

    init(style: Style = .primary) {
        self.style = style
    }

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .foregroundColor(foregroundColor(configuration))
            .background(backgroundColor(configuration))
            .cornerRadius(6.0)
    }

    func foregroundColor(_ configuration: Self.Configuration) -> Color {

        if !isEnabled {
            return Color.secondary
        }

        if style == .secundary {
            if colorScheme == .dark {
                return configuration.isPressed ? Color.primary : Color.white
            } else {
                return configuration.isPressed ? Color.white: Color.primary
            }
        } else {
           return configuration.isPressed ? Color.primary : Color.white
        }
    }

    func backgroundColor(_ configuration: Self.Configuration) -> Color {
        let opacitySecondaryColor = Color.secondary.opacity(0.3)

        if !isEnabled {
            return opacitySecondaryColor
        }

        if style == .secundary {
            return configuration.isPressed ? Color.secondary : opacitySecondaryColor
        } else {
            return configuration.isPressed ? Color.secondary : Color.accentColor
        }
    }
}

// MARK: - Modifier
struct BorderedRoundedCorner: ViewModifier {
    let backgroundColor: Color?

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    if let color = backgroundColor {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(color)
                            .opacity(0.1)
                    }

                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary, lineWidth: 1)
                        .opacity(0.4)
                }
            )
    }
}

struct ShadedBorderedPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(48)
            .background(Color("modal-background-color", bundle: .module))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 4)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            .padding(.all)
    }
}

extension View {
    func borderedRoundedCorner() -> some View {
        modifier(BorderedRoundedCorner(backgroundColor: nil))
    }

    func borderedRoundedCorner(backgroundColor: Color) -> some View {
        modifier(BorderedRoundedCorner(backgroundColor: backgroundColor))
    }

    func shadedBorderedPanel() -> some View {
        modifier(ShadedBorderedPanel())
    }
}
