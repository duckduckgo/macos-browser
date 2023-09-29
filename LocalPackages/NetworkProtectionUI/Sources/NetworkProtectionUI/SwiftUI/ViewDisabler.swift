//
//  ViewDisabler.swift
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

/// Disables a view giving it opacity and making it impossible to interact with.  Most useful on composite views.
///
private struct ViewDisabler: ViewModifier {
    static let disabledOpacity = 0.4
    static let enabledOpacity = 1.0

    @State var disable: Bool

    func body(content: Content) -> some View {
        content.opacity(disable ? Self.disabledOpacity : Self.enabledOpacity)
            .disabled(disable ? true : false)
    }
}

extension View {

    /// Disables a view giving it opacity and making it impossible to interact with.  Most useful on composite views.
    ///
    @ViewBuilder
    func disabled(on condition: Bool) -> some View {
        // This if condition may seem a bit silly and unnecessary, but it seems like the `ViewDisabler`
        // won't be recreated / recalculated unless we split paths here for the condition.
        if condition {
            self.modifier(ViewDisabler(disable: condition))
        } else {
            self.modifier(ViewDisabler(disable: condition))
        }
    }
}
