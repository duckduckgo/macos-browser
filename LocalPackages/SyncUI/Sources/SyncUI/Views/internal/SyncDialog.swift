//
//  SyncDialog.swift
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

struct SyncDialog<Content, Buttons>: View where Content: View, Buttons: View {

    let spacing: CGFloat
    let bottomText: String?
    @ViewBuilder let content: () -> Content
    @ViewBuilder let buttons: () -> Buttons

    init(spacing: CGFloat = 16.0, bottomText: String? = nil, @ViewBuilder content: @escaping () -> Content, @ViewBuilder buttons: @escaping () -> Buttons) {
        self.spacing = spacing
        self.content = content
        self.buttons = buttons
        self.bottomText = bottomText
    }

    var body: some View {
        VStack(spacing: 0) {
            content()
                .padding(.horizontal, 20.0)
                .padding(.bottom, spacing)

            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor))
                .padding(.bottom, 16.0)

            HStack {
                if let bottomText {
                    Spacer()
                    Text(bottomText)
                        .foregroundColor(Color(.blackWhite60))
                }
                Spacer()
                buttons()
            }
            .padding(.horizontal, 20.0)
        }
        .padding(.top, spacing)
        .padding(.bottom, 16.0)
        .frame(minWidth: 360, idealHeight: 314)
        .background(
            Color(.dialogPanelBackground)
        )
    }
}
