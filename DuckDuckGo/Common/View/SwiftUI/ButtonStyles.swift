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

struct StandardButtonStyle: ButtonStyle {

    func makeBody(configuration: Self.Configuration) -> some View {

        let backgroundColor = Color("PWMButtonBackground\(configuration.isPressed ? "-Pressed" : "")")
        let labelColor = Color("PWMButtonLabel")

        configuration.label
            .font(.custom("SFProText-Regular", size: 13))
            .padding(.vertical, 3.5)
            .padding(.horizontal, 12)
            .background(backgroundColor)
            .foregroundColor(labelColor)
            .cornerRadius(5)

    }

}

struct DefaultActionButtonStyle: ButtonStyle {

    let enabled: Bool

    func makeBody(configuration: Self.Configuration) -> some View {

        let enabledBackgroundColor = configuration.isPressed ? Color(NSColor.controlAccentColor).opacity(0.5) : Color(NSColor.controlAccentColor)
        let disabledBackgroundColor = Color.gray.opacity(0.1)
        let labelColor = enabled ? Color("PWMActionButtonLabel") : Color.primary.opacity(0.3)

        configuration.label
            .font(.custom("SFProText-Regular", size: 13))
            .padding(.vertical, 3.5)
            .padding(.horizontal, 12)
            .background(enabled ? enabledBackgroundColor : disabledBackgroundColor)
            .foregroundColor(labelColor)
            .cornerRadius(5)

    }

}

private struct OnTouchDownGestureModifier: ViewModifier {
    @State private var tapped = false
    let callback: () -> Void

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !self.tapped {
                        self.tapped = true
                        self.callback()
                    }
                }
                .onEnded { _ in
                    self.tapped = false
                })
    }
}

extension View {
    func onTouchDownGesture(callback: @escaping () -> Void) -> some View {
        modifier(OnTouchDownGestureModifier(callback: callback))
    }
}

struct TouchDownButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.onTouchDownGesture(callback: configuration.trigger)
    }
}
