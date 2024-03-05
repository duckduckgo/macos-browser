//
//  FocusableTextEditor.swift
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

@available(macOS 12, *)
struct FocusableTextEditor: View {

    @Binding var text: String
    @FocusState var isFocused: Bool

    let cornerRadius: CGFloat = 8.0
    let borderWidth: CGFloat = 0.4
    var characterLimit: Int = 10000

    var body: some View {
        TextEditor(text: $text)
            .frame(height: 150.0)
            .font(.body)
            .foregroundColor(.primary)
            .focused($isFocused)
            .padding(EdgeInsets(top: 3.0, leading: 6.0, bottom: 5.0, trailing: 0.0))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onChange(of: text) {
                text = String($0.prefix(characterLimit))
            }
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.accentColor.opacity(0.5), lineWidth: 4).opacity(isFocused ? 1 : 0).scaleEffect(isFocused ? 1 : 1.04)
                        .animation(isFocused ? .easeIn(duration: 0.2) : .easeOut(duration: 0.0), value: isFocused)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color(.textEditorBorder), lineWidth: borderWidth)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color(.textEditorBackground))
                }
            )
    }
}
