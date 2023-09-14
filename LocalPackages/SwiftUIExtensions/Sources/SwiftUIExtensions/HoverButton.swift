//
//  HoverButton.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

public struct HoverButton: View {

    public let size: CGFloat
    public let backgroundColor: Color
    public let mouseOverColor: Color
    public let imageName: String
    public let imageSize: CGFloat?
    public let action: () -> Void
    public let cornerRadius: CGFloat

    @State public var isHovering = false

    public init(
        size: CGFloat = 32,
        backgroundColor: Color = Color.clear,
        mouseOverColor: Color = Color("ButtonMouseOverColor"),
        imageName: String,
        imageSize: CGFloat = 16,
        cornerRadius: CGFloat,
        action: @escaping () -> Void
    ) {

        self.size = size
        self.backgroundColor = backgroundColor
        self.mouseOverColor = mouseOverColor
        self.imageName = imageName
        self.imageSize = imageSize
        self.cornerRadius = cornerRadius
        self.action = action
    }

    public var body: some View {
        ZStack {

            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(isHovering ? mouseOverColor : backgroundColor)

            Group {
                if NSImage(named: imageName) != nil {
                    Image(imageName)
                        .resizable()
                } else {
                    Image(systemName: imageName)
                        .resizable()
                }
            }
            .frame(width: imageSize ?? size, height: imageSize ?? size)

        }
        .frame(width: size, height: size)
        .link(onHoverChanged: {
            self.isHovering = $0
        }) {
            action()
        }
    }
}
