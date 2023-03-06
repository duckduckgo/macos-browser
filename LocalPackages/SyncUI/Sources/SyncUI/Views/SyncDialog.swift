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

public struct SyncDialog<Content, Buttons>: View where Content: View, Buttons: View {

    public let spacing: CGFloat
    @ViewBuilder public  let content: () -> Content
    @ViewBuilder public let buttons: () -> Buttons

    public init(spacing: CGFloat = 16.0, @ViewBuilder content: @escaping () -> Content, @ViewBuilder buttons: @escaping () -> Buttons) {
        self.spacing = spacing
        self.content = content
        self.buttons = buttons
    }

    public var body: some View {
        VStack(spacing: 0) {
            content()
                .padding(.horizontal, 20.0)
                .padding(.bottom, spacing)

            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor))
                .padding(.bottom, 16.0)

            HStack {
                Spacer()
                buttons()
            }
            .padding(.horizontal, 20.0)
        }
        .padding(.top, spacing)
        .padding(.bottom, 16.0)
        .frame(minWidth: 360, minHeight: 298, idealHeight: 314)

    }
}
