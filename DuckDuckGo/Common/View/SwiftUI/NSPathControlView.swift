//
//  NSPathControlView.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import SwiftUI
import Combine

struct NSPathControlView: NSViewRepresentable {

    typealias NSViewType = NSPathControl

    var url: URL?

    func makeNSView(context: NSViewRepresentableContext<NSPathControlView>) -> NSPathControl {
        let newPathControl = NSPathControl()

        newPathControl.wantsLayer = true
        newPathControl.isEditable = false
        newPathControl.refusesFirstResponder = true
        newPathControl.layer?.cornerRadius = 3.0
        newPathControl.layer?.borderWidth = 1.0

        newPathControl.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        newPathControl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        context.coordinator.alphaCancellable = newPathControl
            .publisher(for: \.isEnabled)
            .map { $0 ? 1.0 : 0.5 }
            .assign(to: \.alphaValue, on: newPathControl)

        context.coordinator.borderColorCancellable = newPathControl
            .publisher(for: \.effectiveAppearance)
            .sink { _ in
                NSAppearance.withAppAppearance {
                    newPathControl.layer?.borderColor = NSColor.divider.cgColor
                }
            }

        return newPathControl
    }

    func updateNSView(_ nsView: NSPathControl, context: NSViewRepresentableContext<NSPathControlView>) {
        nsView.url = url
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }

    final class Coordinator {
        var alphaCancellable: AnyCancellable?
        var borderColorCancellable: AnyCancellable?
    }
}
