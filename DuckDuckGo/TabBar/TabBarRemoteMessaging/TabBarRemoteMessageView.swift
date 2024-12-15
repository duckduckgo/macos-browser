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
    @State private var presentPopup: Bool = false

    let model: TabBarRemoteMessage
    let onClose: () -> Void
    let onTap: (URL) -> Void
    let onHover: () -> Void
    let onHoverEnd: () -> Void

    var body: some View {
        HStack {
            Button(model.buttonTitle) {
                onTap(model.surveyURL)
            }
            .buttonStyle(DefaultActionButtonStyle(
                enabled: true,
                onClose: { onClose() },
                onHoverStart: {
                    onHover()
                },
                onHoverEnd: {
                    onHoverEnd()
                })
            )
            .frame(width: 147)
        }
    }
}

struct TabBarRemoteMessagePopoverContent: View {
    enum Constants {
        static let height: CGFloat = 92
        static let width: CGFloat = 360
    }

    let model: TabBarRemoteMessage

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Image(.daxResponse)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .padding(.leading, 8)
                .padding(.trailing, 16)

            VStack(alignment: .leading, spacing: 0) {
                Text(model.popupTitle)
                    .font(.system(size: 13, weight: .bold))
                    .padding(.bottom, 8)

                Text(model.popupSubtitle)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.trailing, 12)
            .padding([.bottom, .top], 10)
        }
        .frame(width: Constants.width, height: Constants.height)
    }
}

private struct DefaultActionButtonStyle: ButtonStyle {

    public let enabled: Bool
    public let onClose: () -> Void
    public let onHoverStart: () -> Void
    public let onHoverEnd: () -> Void

    public init(
        enabled: Bool,
        onClose: @escaping () -> Void,
        onHoverStart: @escaping () -> Void = {},
        onHoverEnd: @escaping () -> Void = {}
    ) {
        self.enabled = enabled
        self.onClose = onClose
        self.onHoverStart = onHoverStart
        self.onHoverEnd = onHoverEnd
    }

    public func makeBody(configuration: Self.Configuration) -> some View {
        ButtonContent(
            configuration: configuration,
            enabled: enabled,
            onClose: onClose,
            onHoverStart: onHoverStart,
            onHoverEnd: onHoverEnd
        )
    }

    struct ButtonContent: View {
        let configuration: Configuration
        let enabled: Bool
        let onClose: () -> Void
        let onHoverStart: () -> Void
        let onHoverEnd: () -> Void

        @State private var isHovered: Bool = false

        var body: some View {
            let enabledBackgroundColor = configuration.isPressed
            ? Color("PrimaryButtonPressed")
            : (isHovered
               ? Color("PrimaryButtonHover")
               : Color("PrimaryButtonRest"))

            let disabledBackgroundColor = Color.gray.opacity(0.1)
            let enabledLabelColor = configuration.isPressed ? Color.white.opacity(0.8) : Color.white
            let disabledLabelColor = Color.primary.opacity(0.3)

            HStack(spacing: 5) {
                configuration.label
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: { onClose() }) {
                    Image(.close)
                }
                .frame(width: 16, height: 16)
                .buttonStyle(PlainButtonStyle())
            }
            .frame(minWidth: 44)
            .padding(.top, 2.5)
            .padding(.bottom, 3)
            .padding(.horizontal, 7.5)
            .background(enabled ? enabledBackgroundColor : disabledBackgroundColor)
            .foregroundColor(enabled ? enabledLabelColor : disabledLabelColor)
            .cornerRadius(5)
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    onHoverStart()
                } else {
                    onHoverEnd()
                }
            }
        }
    }
}
