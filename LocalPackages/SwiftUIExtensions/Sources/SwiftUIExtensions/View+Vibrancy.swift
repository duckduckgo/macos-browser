//
//  View+Vibrancy.swift
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

public extension View {
    /**
     * Displays `cursor` when the view is hovered.
     *
     * This modifier uses `.onHover` under the hood, so it takes an optional
     * closure parameter that would be called inside the `.onHover` modifier
     * before updating the cursor, removing the need to add a separate `.onHover`
     * modifier.
     */
    func ultraThinVibrancyBackground(or color: Color) -> some View {
        modifier(VibrancyModifier(color: color))
    }
}

private struct VibrancyModifier: ViewModifier {

    let color: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 12.0, *) {
            content.background(.ultraThinMaterial)
        } else {
            content.background(color)
        }
    }
}
