//
//  TabBarRemoteMessageView.swift
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

struct TabBarRemoteMessageView: View {
    @State private var wasViewHovered: Bool = false
    @State private var wasCloseButtonHovered: Bool = false

    let model: TabBarRemoteMessage

    let onClose: () -> Void
    let onTap: (URL) -> Void
    let onHover: () -> Void
    let onHoverEnd: () -> Void
    let onAppear: () -> Void

    var body: some View {
        HStack {
            Text(model.buttonTitle)
                .font(.system(size: 13))
                .fixedSize(horizontal: true, vertical: false)
                .foregroundColor(.white)

            Button(action: { onClose() }) {
                Image(.close)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }
            .frame(width: 16, height: 16)
            .buttonStyle(PlainButtonStyle())
            .background(wasCloseButtonHovered && !wasViewHovered
                        ? Color("PrimaryButtonHover")
                        : Color("PrimaryButtonRest"))
            .cornerRadius(2)
            .onHover { hovering in
                wasCloseButtonHovered = hovering
            }
        }
        .padding(8)
        .background(wasViewHovered
                    ? Color("PrimaryButtonHover")
                    : Color("PrimaryButtonRest"))
        .frame(height: 24)
        .cornerRadius(8)
        .onAppear(perform: { onAppear() })
        .onHover { hovering in
            wasViewHovered = hovering

            if hovering {
                onHover()
            } else {
                onHoverEnd()
            }
        }
    }
}

struct TabBarRemoteMessagePopoverContent: View {
    let model: TabBarRemoteMessage

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(.daxResponse)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 8) {
                Text(model.popupTitle)
                    .font(.system(size: 13, weight: .bold))
                    .padding(.top, 9)

                Text(model.popupSubtitle)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.bottom, 9)
            }
            .frame(width: 236)
        }
        .padding([.top, .bottom], 10)
        .padding(.leading, 12)
        .padding(.trailing, 24)
    }
}
