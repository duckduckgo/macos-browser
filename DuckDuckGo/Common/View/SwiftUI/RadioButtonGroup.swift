//
//  RadioButtonGroup.swift
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

import Foundation
import AppKit

final class RadioButtonGroup: NSObject {

    private class ButtonRef {
        weak var button: NSButton?
        init(button: NSButton) {
            self.button = button
        }
    }

    var selection: Int {
        didSet {
            updateButtons()
            onSelected(selection)
        }
    }

    var onSelected: (Int) -> Void
    private var buttons = [ButtonRef]()

    private func sortedButtons() -> [NSButton] {
        return buttons.sorted { button1, button2 in
            guard let button1 = button1.button,
                  let button2 = button2.button
            else { return false }
            let origin1 = button1.convert(NSPoint.zero, to: nil)
            let origin2 = button2.convert(NSPoint.zero, to: nil)
            return origin1.y > origin2.y
                || (origin1.y == origin2.y && origin1.x < origin2.x)
        }.compactMap { $0.button }
    }

    init(selection: Int, onSelected: @escaping (Int) -> Void) {
        self.selection = selection
        self.onSelected = onSelected
    }

    func add(_ button: NSButton) {
        self.buttons.append(.init(button: button))
        button.target = self
        button.action = #selector(buttonAction(_:))

        updateButtons()
    }

    func remove(_ button: NSButton) {
        _=self.buttons.firstIndex(where: { $0.button === button }).map {
            self.buttons.remove(at: $0)
        }
    }

    private func updateButtons() {
        let buttons = sortedButtons()
        let isFirstResponder = buttons.contains(where: { $0.isFirstResponder })
        for (idx, button) in buttons.enumerated() {
            button.state = idx == selection ? .on : .off
            button.refusesFirstResponder = button.state == .off
            if isFirstResponder && button.state == .on {
                button.makeMeFirstResponder()
            }
        }
    }

    func selectNext() {
        guard buttons.count > selection + 1 else { return }
        selection += 1
    }

    func selectPrevious() {
        guard selection - 1 >= 0 else { return }
        selection -= 1
    }

    @objc func buttonAction(_ sender: NSButton) {
        guard let idx = sortedButtons().firstIndex(of: sender) else {
            assertionFailure("Button not found")
            return
        }
        selection = idx
    }

}
