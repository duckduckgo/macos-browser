//
//  PopoverMessageView.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import AppKit
import Foundation
import SwiftUI

public final class PopoverMessageViewModel: ObservableObject {
    @Published var message: String
    @Published var image: NSImage?
    @Published var buttonText: String?
    @Published public var buttonAction: (() -> Void)?
    var shouldShowCloseButton: Bool
    var shouldPresentMultiline: Bool

    public init(message: String,
                image: NSImage? = nil,
                buttonText: String? = nil,
                buttonAction: (() -> Void)? = nil,
                shouldShowCloseButton: Bool = false,
                shouldPresentMultiline: Bool = true) {
        self.message = message
        self.image = image
        self.buttonText = buttonText
        self.buttonAction = buttonAction
        self.shouldShowCloseButton = shouldShowCloseButton
        self.shouldPresentMultiline = shouldPresentMultiline
    }
}

public struct PopoverMessageView: View {
    @ObservedObject public var viewModel: PopoverMessageViewModel
    var onClick: (() -> Void)?
    var onClose: (() -> Void)?

    public init(viewModel: PopoverMessageViewModel,
                onClick: (() -> Void)?,
                onClose: (() -> Void)?) {
        self.viewModel = viewModel
        self.onClick = onClick
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            ClickableViewRepresentable(onClick: onClick)
                .background(Color.clear)
            HStack(alignment: .top) {
                if let image = viewModel.image {
                    Image(nsImage: image)
                        .padding(.top, 3)
                }

                if viewModel.shouldPresentMultiline {
                    Text(viewModel.message)
                        .font(.body)
                        .fontWeight(.bold)
                        .padding(.leading, 2)
                        .frame(width: 150, alignment: .leading)
                        .frame(minHeight: 22)
                        .lineLimit(nil)
                } else {
                    Text(viewModel.message)
                        .font(.body)
                        .fontWeight(.bold)
                        .padding(.leading, 2)
                        .frame(minHeight: 22)
                        .lineLimit(nil)
                }

                if let text = viewModel.buttonText,
                   let action = viewModel.buttonAction {
                    Button(text, action: {
                        action()
                        onClose?()
                    })
                    .padding(.top, 2)
                    .padding(.leading, 4)
                }

                if viewModel.shouldShowCloseButton {
                    Button(action: {
                        onClose?()
                    }) {
                        Image(.updateNotificationClose)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }
}

final class ClickableView: NSView {
    var onClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        onClick?()
    }
}

struct ClickableViewRepresentable: NSViewRepresentable {
    var onClick: (() -> Void)?

    func makeNSView(context: Context) -> ClickableView {
        let view = ClickableView()
        view.onClick = onClick
        return view
    }

    func updateNSView(_ nsView: ClickableView, context: Context) {
        nsView.onClick = onClick
    }
}
