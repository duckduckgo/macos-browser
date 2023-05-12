//
//  MenuItemButton.swift
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

import Foundation
import SwiftUI

struct MenuItemButton: View {
    private let title: String
    private let textColor: Color
    private let action: () -> Void

    private let highlightAnimationStepSpeed = 0.05

    @State private var isHovered = false
    @State private var animatingTap = false

    init(_ title: String, textColor: Color, action: @escaping () -> Void) {
        self.title = title
        self.textColor = textColor
        self.action = action
    }

    var body: some View {
        Button(action: {
            buttonTapped()
        }) {
            HStack {
                Text(title)
                    .foregroundColor(isHovered ? .white : textColor)
                Spacer()
            }.padding([.top, .bottom], 3)
                .padding([.leading, .trailing], 9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            buttonBackground(highlighted: isHovered)
        )
        .contentShape(Rectangle())
        .cornerRadius(4)
        .onTapGesture {
            buttonTapped()
        }
        .onHover { hovering in
            if !animatingTap {
                isHovered = hovering
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func buttonBackground(highlighted: Bool) -> some View {
        if highlighted {
            return AnyView(
                VisualEffectView(material: .selection, blendingMode: .withinWindow, state: .active, isEmphasized: true))
        } else {
            return AnyView(Color.clear)
        }
    }

    private func buttonTapped() {
        animatingTap = true
        isHovered = false

        DispatchQueue.main.asyncAfter(deadline: .now() + highlightAnimationStepSpeed) {
            isHovered = true

            DispatchQueue.main.asyncAfter(deadline: .now() + highlightAnimationStepSpeed) {
                animatingTap = false
                action()
            }
        }
    }
}
