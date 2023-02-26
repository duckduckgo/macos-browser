//
//  SyncWizardStep.swift
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

struct SyncWizardStep<Content, Buttons>: View where Content: View, Buttons: View {

    let spacing: CGFloat
    @ViewBuilder let content: () -> Content
    @ViewBuilder let buttons: () -> Buttons

    init(spacing: CGFloat = 16.0, @ViewBuilder content: @escaping () -> Content, @ViewBuilder buttons: @escaping () -> Buttons) {
        self.spacing = spacing
        self.content = content
        self.buttons = buttons
    }

    var body: some View {
        VStack(spacing: spacing) {
            content()
                .padding(.horizontal, 20)

            Rectangle()
                .frame(height: 1)
                .foregroundStyle(SeparatorShapeStyle())

            HStack {
                Spacer()
                buttons()
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .frame(minWidth: 360, minHeight: 314)

    }
}
