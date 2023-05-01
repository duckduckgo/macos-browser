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
    let title: String
    let action: () -> Void

    private let highlightAnimationStepSpeed = 0.05

    @State private var isHovered = false
    @State private var animatingTap = false
    @State private var animateToOff = true

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: {
            buttonTapped()
        }) {
            HStack {
                Text(title)
                    .foregroundColor(isHovered ? .white : .primary)
                Spacer()
            }.padding([.top, .bottom], 4)
                .padding([.leading, .trailing], 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isHovered ? Color(.controlAccentColor) : Color.clear)
        )
        .contentShape(Rectangle())
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

    private func buttonTapped() {
        animatingTap = true

        withAnimation(.easeInOut(duration: highlightAnimationStepSpeed)) {
            isHovered = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + highlightAnimationStepSpeed) {
            withAnimation(.easeInOut(duration: highlightAnimationStepSpeed)) {
                isHovered = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + highlightAnimationStepSpeed) {
                animatingTap = false
                isHovered = false
                action()
            }
        }
    }
}
