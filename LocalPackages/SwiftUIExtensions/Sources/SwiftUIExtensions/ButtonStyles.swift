//
//  ButtonStyles.swift
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

import Foundation
import SwiftUI

public struct StandardButtonStyle: ButtonStyle {

    public init() {}

    public func makeBody(configuration: Self.Configuration) -> some View {

        let backgroundColor = configuration.isPressed ? Color(.pwmButtonBackgroundPressed) : Color(.pwmButtonBackground)
        let labelColor = Color(.pwmButtonLabel)

        configuration.label
            .font(.system(size: 13))
            .padding(.top, 2.5)
            .padding(.bottom, 3)
            .padding(.horizontal, 7.5)
            .background(backgroundColor)
            .foregroundColor(labelColor)
            .cornerRadius(5)

    }
}

public struct DefaultActionButtonStyle: ButtonStyle {

    public let enabled: Bool

    public init(enabled: Bool) {
        self.enabled = enabled
    }

    public func makeBody(configuration: Self.Configuration) -> some View {
        ButtonContent(configuration: configuration, enabled: enabled)
    }

    struct ButtonContent: View {
        let configuration: Configuration
        let enabled: Bool
        @State private var isHovered: Bool = false

        var body: some View {
            let enabledBackgroundColor = configuration.isPressed
                ? Color("PrimaryButtonPressed")
                : (isHovered
                    ? Color("PrimaryButtonHover")
                    : Color("PrimaryButtonRest"))

            let disabledBackgroundColor = Color.gray.opacity(0.1)
            let enabledLabelColor = configuration.isPressed ? Color.white.opacity(0.8) : Color.white
            let disabledLabelColor = Color.primary.opacity(0.3)

            configuration.label
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 44)
                .padding(.top, 2.5)
                .padding(.bottom, 3)
                .padding(.horizontal, 7.5)
                .background(enabled ? enabledBackgroundColor : disabledBackgroundColor)
                .foregroundColor(enabled ? enabledLabelColor : disabledLabelColor)
                .cornerRadius(5)
                .onHover { hovering in
                    isHovered = hovering
                }
        }
    }
}

public struct TransparentActionButtonStyle: ButtonStyle {

    public let enabled: Bool

    public init(enabled: Bool) {
        self.enabled = enabled
    }

    public func makeBody(configuration: Self.Configuration) -> some View {

        let enabledForegroundColor = configuration.isPressed ? Color(NSColor.controlAccentColor).opacity(0.5) : Color(NSColor.controlAccentColor)
        let disabledForegroundColor = Color.gray.opacity(0.1)

        configuration.label
            .font(.system(size: 13))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minWidth: 44) // OK buttons will match the width of "Cancel" at least in English
            .padding(.top, 2.5)
            .padding(.bottom, 3)
            .padding(.horizontal, 0)
            .background(Color.clear)
            .foregroundColor(enabled ? enabledForegroundColor : disabledForegroundColor)
            .cornerRadius(5)

    }
}

public struct DismissActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme

    public let textColor: Color

    public init(textColor: Color = .primary) {
        self.textColor = textColor
    }

    public func makeBody(configuration: Self.Configuration) -> some View {
        let backgroundColor = configuration.isPressed ? Color(.windowBackgroundColor) : Color(.controlColor)
        let outerShadowOpacity = colorScheme == .dark ? 0.8 : 0.0

        configuration.label
            .lineLimit(1)
            .font(.system(size: 13))
            .frame(minWidth: 44) // OK buttons will match the width of "Cancel" at least in English
            .padding(.top, 2.5)
            .padding(.bottom, 3)
            .padding(.horizontal, 7.5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(backgroundColor)
                    .shadow(color: .black.opacity(0.1), radius: 0.1, x: 0, y: 1)
                    .shadow(color: .primary.opacity(outerShadowOpacity), radius: 0.1, x: 0, y: -0.6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
            )
            .foregroundColor(textColor)

    }
}

public struct DestructiveActionButtonStyle: ButtonStyle {

    public let enabled: Bool

    public init(enabled: Bool) {
        self.enabled = enabled
    }

    public func makeBody(configuration: Self.Configuration) -> some View {
        let enabledBackgroundColor = configuration.isPressed ? Color(.pwmButtonBackgroundPressed) : .red
        let disabledBackgroundColor = Color.gray.opacity(0.1)
        let labelColor = enabled ? Color.white : Color.primary.opacity(0.3)

        configuration.label
            .lineLimit(1)
            .font(.system(size: 13))
            .frame(minWidth: 44) // OK buttons will match the width of "Cancel" at least in English
            .padding(.top, 2.5)
            .padding(.bottom, 3)
            .padding(.horizontal, 7.5)
            .background(enabled ? enabledBackgroundColor : disabledBackgroundColor)
            .foregroundColor(labelColor)
            .cornerRadius(5)

    }
}

public struct TouchDownButtonStyle: PrimitiveButtonStyle {

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label.onTouchDownGesture(callback: configuration.trigger)
    }
}

private struct OnTouchDownGestureModifier: ViewModifier {
    @State private var tapped = false
    let callback: () -> Void

    func body(content: Content) -> some View {
        content.simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in
            callback()
        })
    }
}

extension View {
    func onTouchDownGesture(callback: @escaping () -> Void) -> some View {
        modifier(OnTouchDownGestureModifier(callback: callback))
    }
}
