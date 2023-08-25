//
//  WindowDraggingView.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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
import Combine

final class WindowDraggingView: NSView {

    private let mouseDownSubject = PassthroughSubject<NSEvent, Never>()

    var mouseDownPublisher: AnyPublisher<NSEvent, Never> {
        mouseDownSubject.eraseToAnyPublisher()
    }

    private enum DoubleClickAction: String {
        case none = "None"
        case miniaturize = "Minimize"
        case zoom = "Maximize"
    }
    @UserDefaultsWrapper(key: .appleActionOnDoubleClick, defaultValue: .zoom)
    private var actionOnDoubleClick: DoubleClickAction

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override var mouseDownCanMoveWindow: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        if NSEvent.isContextClick(event) {
            super.mouseDown(with: event)
            return
        }

        mouseDownSubject.send(event)

        if event.clickCount == 2 {
            performDoubleClickAction()
        } else {
            drag(with: event)
        }
    }

    private func performDoubleClickAction() {
        switch actionOnDoubleClick {
        case .zoom:
            zoom()
        case .miniaturize:
            miniaturize()
        case .none:
            break
        }
    }

    private func zoom() {
        window?.zoom(self)
    }

    private func miniaturize() {
        window?.miniaturize(self)
    }

    private func drag(with event: NSEvent) {
        window?.performDrag(with: event)
    }

}
