//
//  MenuPreview.swift
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

extension CoordinateSpace {
    static let windowCoordinateSpaceName = "windowCoordinateSpace"
    static let window = CoordinateSpace.named(windowCoordinateSpaceName)
}

#if DEBUG

struct MenuPreview: View {
    let menu: NSMenu

    var body: some View {
        guard #available(macOS 13.0, *) else { fatalError() }

        return HStack(spacing: 0) {
            ForEach(menu.items.indices, id: \.self) { idx in
                MenuPreviewButton(menuItem: menu.items[idx], bold: idx == 0)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .coordinateSpace(name: CoordinateSpace.windowCoordinateSpaceName)
    }
}

@available(macOS 13.0, *)
struct MenuPreviewButton: View {

    let menuItem: NSMenuItem
    let bold: Bool

    @State var frame: CGRect = .zero
    @State var isMenuShown = false

    var body: some View {
        Button(menuItem.title) {
            isMenuShown = true
            menuItem.submenu?.popUp(positioning: nil,
                                    at: NSPoint(x: frame.minX, y: frame.maxY + 4),
                                    in: NSApp.keyWindow!.contentView)
            isMenuShown = false
        }
        .buttonStyle(MainMenuItemButtonStyle(isBold: bold, isMenuShown: isMenuShown))
        .background(
            GeometryReader { proxy in
                Color.clear.onChange(of: proxy.size) { _ in
                    frame = proxy.frame(in: .window)
                }
            }
        )
    }

}

@available(macOS 13.0, *)
struct MainMenuItemButtonStyle: ButtonStyle {

    let isBold: Bool
    let isMenuShown: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(isBold ? .bold : .regular)
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .background(configuration.isPressed || isMenuShown ? Color.gray : Color.clear)
    }
}

#endif
