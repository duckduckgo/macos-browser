//
//  FocusableTextField.swift
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

extension TextField {

#if !APPSTORE
    @available(macOS, obsoleted: 12.0, message: "This needs to be cleaned up")
    @ViewBuilder
    func focusedOnAppear() -> some View {
        if #available(macOS 12.0, *) {
            TextFieldFocusedOnAppear(textField: self)
        } else {
            self
        }
    }
#else
    @ViewBuilder
    func focusedOnAppear() -> some View {
        TextFieldFocusedOnAppear(textField: self)
    }
#endif

}

@available(macOS 12.0, *)
struct TextFieldFocusedOnAppear<Label: View>: View {

    let textField: TextField<Label>
    @FocusState private var focusState: Bool

    init(textField: TextField<Label>) {
        self.textField = textField
    }

    var body: some View {
        textField
            .focused($focusState)
            .onAppear {
                DispatchQueue.main.async {
                    focusState = true
                }
            }
    }
}
