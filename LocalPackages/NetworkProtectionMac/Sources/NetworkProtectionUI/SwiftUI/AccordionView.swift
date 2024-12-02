//
//  AccordionView.swift
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

import Foundation
import SwiftUI

struct SideMenuStyle: MenuStyle {
    func makeBody(configuration: Configuration) -> some View {
        Menu(configuration)
            .menuStyle(DefaultMenuStyle())
            .frame(maxWidth: .infinity, alignment: .leading) // Align the menu to the leading edge
    }
}

struct AccordionView<Label: View, Submenu: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    private var label: (Bool) -> Label
    private let submenu: () -> Submenu

    private var highlightAnimationStepSpeed = AnimationConstants.highlightAnimationStepSpeed

    @State private var isHovered = false
    @State private var highlightOverride: Bool?
    @State private var showSubmenu = false

    private var isHighlighted: Bool {
        highlightOverride ?? isHovered
    }

    init(@ViewBuilder label: @escaping (Bool) -> Label,
         @ViewBuilder submenu: @escaping () -> Submenu) {

        self.label = label
        self.submenu = submenu
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .cornerRadius(4)
    }

    private func buttonBackground(highlighted: Bool) -> some View {
        if highlighted {
            return AnyView(
                VisualEffectView(material: .selection, blendingMode: .withinWindow, state: .active, isEmphasized: true))
        } else {
            return AnyView(Color.clear)
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Button(action: {
                buttonTapped()
            }) {
                HStack {
                    label(isHovered)
                    Spacer()

                    if showSubmenu {
                        Image(systemName: "chevron.down") // Chevron pointing right
                            .foregroundColor(.gray)
                    } else {
                        Image(systemName: "chevron.right") // Chevron pointing right
                            .foregroundColor(.gray)
                    }
                }.padding([.top, .bottom], 3)
                    .padding([.leading, .trailing], 9)
            }.buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    buttonBackground(highlighted: isHighlighted)
                )
                .onTapGesture {
                    buttonTapped()
                }
                .onHover { hovering in
                    isHovered = hovering
                }

            if showSubmenu {
                VStack(spacing: 0) {
                    submenu()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func buttonTapped() {
        highlightOverride = false

        DispatchQueue.main.asyncAfter(deadline: .now() + highlightAnimationStepSpeed) {
            highlightOverride = true

            DispatchQueue.main.asyncAfter(deadline: .now() + highlightAnimationStepSpeed) {
                highlightOverride = nil
                showSubmenu.toggle()
            }
        }
    }
}
