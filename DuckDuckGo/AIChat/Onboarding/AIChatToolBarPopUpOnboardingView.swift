//
//  AIChatToolBarPopUpOnboardingView.swift
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

struct AIChatToolBarPopUpOnboardingView: View {
    @ObservedObject var viewModel: AIChatToolBarPopUpOnboardingViewModel

    enum Constants {
        static let verticalSpacing: CGFloat = 16
        static let panelWidth: CGFloat = 310
        static let panelHeight: CGFloat = 148
    }

    var body: some View {
        VStack(spacing: Constants.verticalSpacing) {
            VStack(alignment: .leading, spacing: Constants.verticalSpacing) {
                Text(UserText.aiChatOnboardingPopoverTitle)
                    .font(.headline)

                if #available(macOS 12, *) {
                    // Use Markdown for macOS 12 and newer
                    // .init is required for markdown to be correctly parsed from NSLocalizedString
                    Text(.init(UserText.aiChatOnboardingPopoverMessageMarkdown))
                } else {
                    // Fallback for earlier macOS versions
                    Text(UserText.aiChatOnboardingPopoverMessageFallback)
                }
            }

            HStack {
                createButton(title: UserText.aiChatOnboardingPopoverCTAReject,
                             style: StandardButtonStyle(),
                             action: viewModel.rejectToolbarIcon)

                createButton(title: UserText.aiChatOnboardingPopoverCTAAccept,
                             style: DefaultActionButtonStyle(enabled: true),
                             action: viewModel.acceptToolbarIcon)
            }
        }
        .padding()
        .frame(width: Constants.panelWidth, height: Constants.panelHeight)
    }

    private func createButton(title: String, style: some ButtonStyle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .fontWeight(.light)
                .frame(maxWidth: .infinity)
                .frame(height: 22)
        }
        .buttonStyle(style)
        .padding(0)
    }
}

#Preview {
    AIChatToolBarPopUpOnboardingView(viewModel: AIChatToolBarPopUpOnboardingViewModel())
}
