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

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .foregroundColor(isHovering ? Color.black.opacity(0.06) : Color.blackWhite3)
                .cornerRadius(8)

            HStack(alignment: .top) {

                Image(viewModel.image)
                    .resizable()
                    .frame(width: 48, height: 48)
                    .padding(.top, 14)

                VStack(alignment: .leading) {

                    Text(viewModel.title)
                        .font(.system(size: 13).bold())
                        .multilineTextAlignment(.leading)

                    Text(viewModel.subtitle)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 1)
                        .padding(.bottom, 6)

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
                .padding(.top, 8)
                .padding(.bottom, 14)
                .padding(.trailing, 40)
            }
            .padding(.leading, 8)

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
        HomePage.Views.CloseButton(icon: .close) {
            viewModel.dismissButtonAction?()
        }
        .visibility(isHovering ? .visible : .invisible)
        .padding(6)
    }
}

#Preview {
    SyncPromoView(viewModel: SyncPromoViewModel(touchpointType: .bookmarks, primaryButtonAction: {}, dismissButtonAction: {}))
}
