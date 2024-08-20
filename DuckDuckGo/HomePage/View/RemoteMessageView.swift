//
//  RemoteMessageView.swift
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
import RemoteMessaging
import SwiftUIExtensions

struct RemoteMessageView: View {

    let viewModel: RemoteMessageViewModel

    @State var isHovering = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .foregroundColor(Color.blackWhite3)
                .cornerRadius(8)
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    image

                    VStack(alignment: .leading, spacing: 8) {
                        title
                        subtitle
                    }
                    .padding(.leading, viewModel.image == nil ? 8 : 0)

                    Spacer(minLength: 4)

                    // Display single button on the right
                    if case .bigSingleAction = viewModel.modelType {
                        button
                    }
                }
                .padding(.trailing, 16)

                // Display two buttons on the bottom
                if case .bigTwoAction = viewModel.modelType {
                    HStack(spacing: 10) {
                        buttons
                        Spacer()
                    }
                    .padding(.top, 4)
                    .padding(.leading, 60)
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 16)
            .padding(.vertical, 16)

            HStack {
                Spacer()
                VStack {
                    closeButton
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 2)
        .onHover { isHovering in
            self.isHovering = isHovering
        }
        .onAppear(perform: viewModel.onDidAppear)
        .onDisappear(perform: viewModel.onDidDisappear)
    }

    private var closeButton: some View {
        HomePage.Views.CloseButton(icon: .close) {
            viewModel.onDidClose(.close)
        }
        .visibility(isHovering ? .visible : .invisible)
        .padding(6)
    }

    private var image: some View {
        Group {
            if let image = viewModel.image {
                Image(image)
                    .frame(width: 48, height: 48)
            } else {
                EmptyView()
            }
        }
    }

    private var title: some View {
        Text(viewModel.title)
            .font(.system(size: 13).bold())
   }

    @ViewBuilder
    private var subtitle: some View {
        if #available(macOS 12.0, *), let attributed = try? AttributedString(markdown: viewModel.subtitle) {
            Text(attributed)
        } else {
            Text(viewModel.subtitle)
        }
    }

    /// Single button is always "standard" (i.e. not prominent/blue) and uses large control size.
    private var button: some View {
        Group {
            if let buttonModel = viewModel.buttons.first {
                buttonModel.standardButton
                    .controlSize(.large)
            } else {
                EmptyView()
            }
        }
    }

    /// Two buttons are displayed on the bottom of the view and use regular control size.
    private var buttons: some View {
        ForEach(viewModel.buttons, id: \.title, content: \.button)
    }
}

extension RemoteMessageButtonViewModel {
    var button: some View {
        Group {
            if actionStyle == .default {
                primaryButton
            } else {
                standardButton
            }
        }
    }

    var primaryButton: some View {
        Group {
            if #available(macOS 12.0, *) {
                standardButton
                    .buttonStyle(.borderedProminent)
            } else {
                standardButton
                    .buttonStyle(DefaultActionButtonStyle(enabled: true))
            }
        }
    }

    var standardButton: some View {
        Button(action: action) {
            Text(title)
        }
    }
}

#Preview("Small") {
    let small = RemoteMessageModelType.small(
        titleText: "Title Goes Here",
        descriptionText: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Etiam eget elit vel ex dapibus mattis ut et leo. Curabitur ut dolor id est blandit rhoncus ac id metus."
    )

    return RemoteMessageView(viewModel: .init(messageId: "1", modelType: small, onDidClose: { _ in }, onDidAppear: {}, onDidDisappear: {}, openURLHandler: { _ in }))
}

#Preview("Medium") {
    let medium = RemoteMessageModelType.medium(
        titleText: "Update Available!",
        descriptionText: "A new version of DuckDuckGo Browser is available. Update now to enjoy improved privacy features and enhanced performance.",
        placeholder: .appUpdate
    )

    return RemoteMessageView(viewModel: .init(messageId: "1", modelType: medium, onDidClose: { _ in }, onDidAppear: {}, onDidDisappear: {}, openURLHandler: { _ in }))
}

#Preview("Big Single Action") {
    let bigSingleAction = RemoteMessageModelType.bigSingleAction(
        titleText: "Update Available!",
        descriptionText: "A new version of DuckDuckGo Browser is available. Update now to enjoy improved privacy features and enhanced performance.",
        placeholder: .appUpdate,
        primaryActionText: "Update Now",
        primaryAction: .dismiss
    )

    return RemoteMessageView(viewModel: .init(messageId: "1", modelType: bigSingleAction, onDidClose: { _ in }, onDidAppear: {}, onDidDisappear: {}, openURLHandler: { _ in }))
}

#Preview("Big Single Action #2") {
    let bigSingleAction = RemoteMessageModelType.bigSingleAction(
        titleText: "Tell Us Why You Left Privacy Pro",
        descriptionText: "By taking our brief survey, you'll help us improve Privacy Pro for all subscribers.",
        placeholder: .privacyShield,
        primaryActionText: "Take Survey...",
        primaryAction: .dismiss
    )

    return RemoteMessageView(viewModel: .init(messageId: "1", modelType: bigSingleAction, onDidClose: { _ in }, onDidAppear: {}, onDidDisappear: {}, openURLHandler: { _ in }))
}

#Preview("Big Two Action") {
    let bigTwoAction = RemoteMessageModelType.bigTwoAction(
        titleText: "macOS Update Recommended",
        descriptionText: "Support for macOS Big Sur is ending soon. Update to macOS Monterey or newer <b>before July 8, 2024</b>, to keep getting the latest browser updates and improvements.",
        placeholder: .criticalUpdate,
        primaryActionText: "How To Update macOS",
        primaryAction: .appStore,
        secondaryActionText: "Remind Me Later",
        secondaryAction: .dismiss
    )

    return RemoteMessageView(viewModel: .init(messageId: "1", modelType: bigTwoAction, onDidClose: { _ in }, onDidAppear: {}, onDidDisappear: {}, openURLHandler: { _ in }))
}
