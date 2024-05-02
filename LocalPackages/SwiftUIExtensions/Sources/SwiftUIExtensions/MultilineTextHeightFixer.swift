//
//  MultilineTextHeightFixer.swift
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

import Combine
import Foundation
import SwiftUI

/// Fixes the height for multiline text fields, which seem to suffer from a layout issue where
/// their height isn't properly honored.
///
private struct MultilineTextHeightFixer: ViewModifier {
    @State var textHeight: CGFloat?

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear // This is just to have something to attach .onReceive to.
                        .onReceive(Just(geometry.size)) { _ in
                            textHeight = geometry.size.height
                        }
                })
            .frame(height: textHeight)
    }
}

public extension View {

    /// Meant to be used for multiline-text.  This is currently only applying a modifier
    ///
    @ViewBuilder
    func multilineText() -> some View {
        self.fixedSize(horizontal: false, vertical: true)
            .modifier(MultilineTextHeightFixer())
    }
}
