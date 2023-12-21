//
//  SyncWarningMessage.swift
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
import SwiftUIExtensions

struct SyncWarningMessage: View {
    let title: String
    let message: String
    let buttonTitle: String?
    let buttonAction: (() -> Void)?

    init(title: String, message: String, buttonTitle: String? = nil, buttonAction: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.buttonAction = buttonAction
    }

    var body: some View {
        PreferencePaneSection(verticalPadding: 16) {
            HStack(alignment: .top, spacing: 8) {
                Text("⚠️")
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).bold()
                    Text(message)
                    if let buttonTitle, let buttonAction {
                        Button(buttonTitle, action: buttonAction)
                            .padding(.top, 8)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(width: 512, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).foregroundColor(Color("AlertBubbleBackground")))
    }
}
