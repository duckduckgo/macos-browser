//
//  BannerView.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

final class BannerMessageViewController: NSHostingController<BannerView> {
    let viewModel: BannerViewModel

    init(message: String,
         image: NSImage,
         buttonText: String,
         buttonAction: @escaping (() -> Void),
         closeAction: @escaping (() -> Void)) {
        self.viewModel = .init(message: message,
                               image: image,
                               buttonText: buttonText,
                               buttonAction: buttonAction,
                               closeAction: closeAction)

        super.init(rootView: BannerView(viewModel: viewModel))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class BannerViewModel: ObservableObject {
    @Published var message: String
    @Published var image: NSImage
    @Published var buttonText: String
    @Published var buttonAction: (() -> Void)
    @Published var closeAction: (() -> Void)

    public init(message: String,
                image: NSImage,
                buttonText: String,
                buttonAction: @escaping (() -> Void),
                closeAction: @escaping (() -> Void)) {
        self.message = message
        self.image = image
        self.buttonText = buttonText
        self.buttonAction = buttonAction
        self.closeAction = closeAction
    }
}

struct BannerView: View {
    @ObservedObject public var viewModel: BannerViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: viewModel.image)

            Text(viewModel.message)

            Button {
                viewModel.buttonAction()
            } label: {
                Text(viewModel.buttonText)
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))

            Spacer()

            Button(action: {
                viewModel.closeAction()
            }) {
                Image(.closeSmall)
                    .padding()
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.leading, 19)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
