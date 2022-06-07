//
//  TextButton.swift
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

struct TextButton: View {
    
    let title: String
    let color: Color
    let hoverColor: Color?
    let underlineOnHover: Bool
    let action: () -> Void

    @State var isHovering = false
    
    init(_ title: String,
         color: Color = Color("LinkBlueColor"),
         hoverColor: Color? = nil,
         underlineOnHover: Bool = false,
         action: @escaping () -> Void) {

        self.title = title
        self.color = color
        self.hoverColor = hoverColor
        self.underlineOnHover = underlineOnHover
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .foregroundColor(isHovering && hoverColor != nil ? hoverColor! : color)
                .optionalUnderline(underlineOnHover && isHovering)
        }
        .buttonStyle(.plain)
        .cursor(.pointingHand)
        .onHover(update: $isHovering)
    }

}
