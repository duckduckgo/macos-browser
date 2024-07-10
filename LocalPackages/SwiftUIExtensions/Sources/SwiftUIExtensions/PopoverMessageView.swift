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

    public init(message: String,
                image: NSImage? = nil,
                buttonText: String? = nil,
                buttonAction: (() -> Void)? = nil) {
        self.message = message
        self.image = image
        self.buttonText = buttonText
        self.buttonAction = buttonAction
    }
}

public struct PopoverMessageView: View {
    @ObservedObject public var viewModel: PopoverMessageViewModel
    var onClick: () -> Void

    public init(viewModel: PopoverMessageViewModel, onClick: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onClick = onClick
    }

    public var body: some View {
        ZStack {
            ClickableViewRepresentable(onClick: onClick)
                .background(Color.clear)
            HStack {
                if let image = viewModel.image {
                    Image(nsImage: image)
                }

                Text(viewModel.message)
                    .font(.body)
                    .fontWeight(.bold)
                    .padding(.leading, 4)
                    .padding(.trailing, 7)

                if let text = viewModel.buttonText,
                   let action = viewModel.buttonAction {
                    Button(text, action: action)
                        .padding(.top, 2)
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
    var onClick: () -> Void

    func makeNSView(context: Context) -> ClickableView {
        let view = ClickableView()
        view.onClick = onClick
        return view
    }

    func updateNSView(_ nsView: ClickableView, context: Context) {
        nsView.onClick = onClick
    }
}
