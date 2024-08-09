//
//  CloseButton.swift
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

import SwiftUI
import SwiftUIExtensions

extension HomePage.Views {

    struct CloseButton: View {
        let icon: NSImage
        let size: CGFloat
        let action: () -> Void
        let foreGroundColor: Color = .homeFavoritesBackground
        let foregroundColorOnHover: Color = .homeFavoritesHover

        @State var isHovering = false

        var body: some View {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(isHovering ? foregroundColorOnHover : foreGroundColor)
                        .frame(width: size, height: size)
                    Image(nsImage: icon)
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(.plain)
            .onHover { isHovering in
                self.isHovering = isHovering
            }
        }
    }

}
