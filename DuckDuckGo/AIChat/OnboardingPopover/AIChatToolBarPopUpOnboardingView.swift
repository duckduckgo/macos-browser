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

                Text(UserText.aiChatOnboardingPopoverMessage1) +
                Text(" ") +
                Text(UserText.aiChatOnboardingPopoverMessage1).bold()
            }

            HStack {
                createButton(title: UserText.aiChatOnboardingPopoverCTAReject,
                             action: viewModel.rejectToolbarIcon,
                             style: StandardButtonStyle())

                createButton(title: UserText.aiChatOnboardingPopoverCTAAccept,
                             action: viewModel.acceptToolbarIcon,
                             style: DefaultActionButtonStyle(enabled: true))
            }
        }
        .padding()
        .frame(width: Constants.panelWidth, height: Constants.panelHeight)
    }

    private func createButton(title: String, action: @escaping () -> Void, style: some ButtonStyle) -> some View {
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
