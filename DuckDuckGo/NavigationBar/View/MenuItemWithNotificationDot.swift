//
//  MenuItemWithNotificationDot.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

/// View that represents a menu item that has a blue notification dot at the right.
struct MenuItemWithNotificationDot: View {
    let leftImage: NSImage
    let title: String
    var onTapMenuItem: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? .menuItemHover : Color.clear)
                .padding([.leading, .trailing], 5)
                .frame(maxWidth: .infinity)

            HStack(spacing: 0) {
                Image(nsImage: leftImage)
                    .resizable()
                    .foregroundColor(isHovered ? .white : .blackWhite100)
                    .frame(width: 16, height: 16)
                    .padding(.trailing, 6)
                    .padding(.leading, 14)

                Text(title)
                    .foregroundColor(isHovered ? .white : .blackWhite100.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Circle()
                    .fill(isHovered ? .white : .updateIndicator)
                    .frame(width: 7, height: 7)
                    .padding(.trailing, 14)
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTapMenuItem()
        }
    }
}
