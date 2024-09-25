//
//  Dialog.swift
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

public struct Spacing {
    let hSpacing: CGFloat
    let contentsVSpacing: CGFloat
    let buttonsVPSpacing: CGFloat

    public static var defaultSpacing: Spacing {
        Spacing(hSpacing: 20.0, contentsVSpacing: 20.0, buttonsVPSpacing: 16.0)
    }
}

public struct Dialog<Content, Buttons>: View where Content: View, Buttons: View {

    public let spacing: Spacing
    @ViewBuilder let content: () -> Content
    @ViewBuilder let buttons: () -> Buttons

    public init(spacing: Spacing = Spacing.defaultSpacing,
                @ViewBuilder content: @escaping () -> Content,
                @ViewBuilder buttons: @escaping () -> Buttons) {

        self.spacing = spacing
        self.content = content
        self.buttons = buttons
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: spacing.contentsVSpacing) {
                content()
                    .padding(.horizontal, spacing.hSpacing)
            }
            .padding(.vertical, spacing.contentsVSpacing)

            Divider()

            Group {
                HStack {
                    buttons()
                }
                .padding(.horizontal, spacing.hSpacing)
                .padding(.vertical, spacing.buttonsVPSpacing)
            }
        }
    }

}
