//
//  SyncPromoView.swift
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

struct SyncPromoView: View {

    let viewModel: SyncPromoViewModel
    @State var isHovering = false
    var hasSecondaryButton: Bool = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .foregroundColor(isHovering ? Color.black.opacity(0.06) : Color.blackWhite3)
                .cornerRadius(8)

            HStack(alignment: hasSecondaryButton ? .top : .center) {
                Image(viewModel.image)
                    .resizable()
                    .frame(width: 48, height: 48)
                    .padding(.top, hasSecondaryButton ? 14 : 0)

                VStack(alignment: .leading) {

                    Text(viewModel.title)
                        .font(.system(size: 13).bold())
                        .multilineTextAlignment(.leading)
                        .multilineText()

                    Text(viewModel.subtitle)
                        .multilineTextAlignment(.leading)
                        .multilineText()
                        .padding(.top, hasSecondaryButton ? 1 : 0)
                        .padding(.bottom, hasSecondaryButton ? 6 : 2)

                    if hasSecondaryButton {
                        HStack {
                            Button(viewModel.secondaryButtonTitle) {
                                viewModel.dismissButtonAction?()
                            }
                                    .buttonStyle(DismissActionButtonStyle())

                            Button(viewModel.primaryButtonTitle) {
                                viewModel.primaryButtonAction?()
                            }
                                    .buttonStyle(DefaultActionButtonStyle(enabled: true))
                        }
                    }
                }
                .padding(.top, hasSecondaryButton ? 8 : 0)
                .padding(.bottom, hasSecondaryButton ? 14 : 0)
                .padding(.trailing, hasSecondaryButton ? 40 : 0)

                if !hasSecondaryButton {
                    Spacer()

                    Button(viewModel.primaryButtonTitle) {
                        viewModel.primaryButtonAction?()
                    }
                    .buttonStyle(DismissActionButtonStyle())
                    .padding(.trailing, 32)
                }
            }
            .padding(.leading, 8)
            .padding(.vertical, hasSecondaryButton ? 0 : 8)

            HStack {
                Spacer()
                VStack {
                    closeButton
                    Spacer()
                }
            }
        }
        .onHover { isHovering in
            self.isHovering = isHovering
        }
    }

    private var closeButton: some View {
        HomePage.Views.CloseButton(icon: .close, size: 16) {
            viewModel.dismissButtonAction?()
        }
        .visibility(isHovering ? .visible : .invisible)
        .padding(6)
    }
}

#Preview {
    SyncPromoView(viewModel: SyncPromoViewModel(touchpointType: .bookmarks, primaryButtonAction: {}, dismissButtonAction: {}), hasSecondaryButton: false)
}
