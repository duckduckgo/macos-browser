//
//  SecureTextField.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

/// View which uses the provided `isVisible` property to display either a `TextField` or a `SecureField`
struct SecureTextField: View {

    @Binding var textValue: String
    var isVisible: Bool
    var bottomPadding: CGFloat = 0

    var body: some View {
        if isVisible {

            TextField("", text: $textValue)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.bottom, bottomPadding)
        } else {

            SecureField("", text: $textValue)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.bottom, bottomPadding)
        }
    }
}

/// View which provides a Button styled to show/hide text with an action that toggles the provided `isVisible` property
struct SecureTextFieldButton: View {

    @Binding var isVisible: Bool
    var toolTipHideText: String
    var toolTipShowText: String

    var body: some View {
        Button {
            isVisible = !isVisible
        } label: {
            Image(.secureEyeToggle)
        }
        .buttonStyle(PlainButtonStyle())
        .tooltip(isVisible ? toolTipHideText : toolTipShowText)
    }
}

/// View which uses the provided `isVisible` property to display either the provided `text` or a string of `•`
struct HiddenText: View {

    var isVisible: Bool
    var text: String
    var hiddenTextLength: Int

    var body: some View {
        if isVisible {
            Text(text)
        } else {
            Text(text.isEmpty ? "" : String(repeating: "•", count: hiddenTextLength))
        }
    }
}

/// View which provides a Button styled to copy text which executes the provided `copyAction`
struct CopyButton: View {

    var copyAction: () -> Void

    var body: some View {
        Button {
            copyAction()
        } label: {
            Image(.copy)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
