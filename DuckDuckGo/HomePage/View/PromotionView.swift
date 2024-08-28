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

typealias PromotionViewModel = HomePage.Models.PromotionViewModel

extension HomePage.Views {

    /// A `PromotionView` is intended to be displayed on the new tab home page, and used to promote a feature, product etc
    struct PromotionView: View {

        @EnvironmentObject var viewModel: PromotionViewModel

        @State var isHovering = false

        var body: some View {
            HStack(spacing: 8) {

                imageView

                Spacer(minLength: 4)

                descriptionView

                Spacer(minLength: 4)

                proceedButtonView

                Spacer(minLength: 4)

                closeButton

            }
            .padding([.horizontal], 16)
            .padding([.vertical], 16)
            .background(Color.blackWhite3)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onHover { isHovering in
                self.isHovering = isHovering
            }
        }

        private var imageView: some View {
            Image(viewModel.image)
                .resizable()
                .frame(width: 48, height: 48)
        }

        private var descriptionView: some View {
            Text(viewModel.description)
                .font(.system(size: 13))
        }

        private var proceedButtonView: some View {
            Button(action: viewModel.proceedAction) {
                Text(viewModel.proceedButtonText)
                    .padding([.horizontal], 16)
                    .padding([.vertical], 5)
            }
                .controlSize(.large)
        }

        private var closeButton: some View {
            CloseButton(icon: .close) {
                viewModel.closeAction()
            }
            .visibility(isHovering ? .visible : .invisible)
            .padding(6)
        }
    }
}

#Preview {
    return HomePage.Views.PromotionView()
        .environmentObject(PromotionViewModel.freemiumPIRPromotion(proceedAction: {}, closeAction: {}))
}
