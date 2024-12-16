//
//  PromotionView.swift
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

typealias PromotionViewModel = HomePage.Models.PromotionViewModel

extension HomePage.Views {

    /// A `PromotionView` is intended to be displayed on the new tab home page, and used to promote a feature, product etc
    struct PromotionView: View {

        var viewModel: PromotionViewModel

        @EnvironmentObject var settingsModel: HomePage.Models.SettingsModel

        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.homeFavoritesGhost, style: StrokeStyle(lineWidth: 1.0))
                    .homePageViewBackground(settingsModel.customBackground)
                    .cornerRadius(12)
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        image

                        textContent

                        Spacer(minLength: 4)

                        button

                    }
                    .padding(.trailing, 16)
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
        }

        private var closeButton: some View {
            HomePage.Views.CloseButton(icon: .close, size: 16) {
                viewModel.closeAction()
            }
            .padding(6)
        }

        private var image: some View {
            Group {
                Image(viewModel.image)
                    .resizable()
                    .frame(width: 48, height: 48)
            }
        }

        private var textContent: some View {
            VStack(alignment: .leading, spacing: viewModel.title == nil ? 0 : 8) {
                title
                description.foregroundColor(Color(.greyText))
            }
        }

        private var title: some View {
            Group {
                if let title = viewModel.title {
                    Text(verbatim: title)
                        .font(.system(size: 13).bold())
                } else {
                    EmptyView()
                }
            }
       }

        @ViewBuilder
        private var description: some View {
            if #available(macOS 12.0, *), let attributed = try? AttributedString(markdown: viewModel.description) {
                Text(attributed)
            } else {
                Text(verbatim: viewModel.description)
            }
        }

        private var button: some View {
            Group {
                Button {
                    Task { @MainActor in
                        await viewModel.proceedAction()
                    }
                } label: {
                    Text(verbatim: viewModel.proceedButtonText)
                }
                .controlSize(.large)
            }
        }
    }
}

#Preview {
    return HomePage.Views.PromotionView(viewModel: PromotionViewModel.freemiumDBPPromotion(proceedAction: {}, closeAction: {}))
        .frame(height: 85)
        .environmentObject(HomePage.Models.SettingsModel())

}
