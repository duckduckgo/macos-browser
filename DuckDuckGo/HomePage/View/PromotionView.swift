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
                            if viewModel.title != nil {
                                title
                            }
                            subtitle
                        }
                        .padding(.leading, 0)

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
            .onHover { isHovering in
                self.isHovering = isHovering
            }
        }

        private var closeButton: some View {
            HomePage.Views.CloseButton(icon: .close, size: 16) {
                viewModel.closeAction()
            }
            .visibility(isHovering ? .visible : .invisible)
            .padding(6)
        }

        private var image: some View {
            Group {
                Image(viewModel.image)
                    .resizable()
                    .frame(width: 48, height: 48)
            }
        }

        private var title: some View {
            Text(viewModel.title!)
                .font(.system(size: 13).bold())
       }

        private var subtitle: some View {
            Text(viewModel.subtitle)
        }

        private var button: some View {
            Group {
                Button(action: viewModel.proceedAction) {
                    Text(viewModel.proceedButtonText)
                }
            }
        }
    }
}

#Preview {
    return HomePage.Views.PromotionView(viewModel: PromotionViewModel.freemiumDBPPromotion(proceedAction: {}, closeAction: {}))
}
