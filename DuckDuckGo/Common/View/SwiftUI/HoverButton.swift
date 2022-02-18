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

struct HoverButton: View {

    let size: CGFloat
    let backgroundColor: Color
    let imageName: String
    let imageSize: CGFloat?
    let action: () -> Void

    @State var isHovering = false

    init(size: CGFloat = 32, backgroundColor: Color = Color.clear, imageName: String, imageSize: CGFloat? = nil, action: @escaping () -> Void) {
        self.size = size
        self.backgroundColor = backgroundColor
        self.imageName = imageName
        self.imageSize = imageSize
        self.action = action
    }

    var body: some View {
        Group {
            Group {
                if let image = NSImage(named: imageName) {
                    Image(nsImage: image)
                        .resizable()
                } else if #available(macOS 11, *) {
                    Image(systemName: imageName)
                        .resizable()
                }
            }
            .frame(width: imageSize ?? size, height: imageSize ?? size)

        }
        .frame(width: size, height: size)
        .cornerRadius(8)
        .background(RoundedRectangle(cornerRadius: 8).foregroundColor(isHovering ? Color("ButtonMouseOverColor") : backgroundColor))
        .link(onHoverChanged: {
            self.isHovering = $0
        }) {
            action()
        }

    }

}
