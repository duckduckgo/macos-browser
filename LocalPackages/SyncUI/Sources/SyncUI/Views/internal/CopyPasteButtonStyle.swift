//
//  CopyPasteButtonStyle.swift
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

struct CopyPasteButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    let verticalPadding: CGFloat

    init(verticalPadding: CGFloat = 6.0) {
        self.verticalPadding = verticalPadding
    }

    func makeBody(configuration: Self.Configuration) -> some View {

        let color: Color = configuration.isPressed ? Color(NSColor.windowBackgroundColor) : Color(NSColor.controlColor)

        let outerShadowOpacity = colorScheme == .dark ? 0.8 : 0.0

        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(color)
                    .shadow(color: .black.opacity(0.1), radius: 0.1, x: 0, y: 1)
                    .shadow(color: .primary.opacity(outerShadowOpacity), radius: 0.1, x: 0, y: -0.6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
            )
    }
}
