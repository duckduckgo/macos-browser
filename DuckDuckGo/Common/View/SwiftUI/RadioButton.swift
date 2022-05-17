//
//  RadioButton.swift
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

import SwiftUI
import AppKit
import Carbon.HIToolbox

final class CustomRadioButton: NSButton {

    var group: RadioButtonGroup {
        didSet {
            guard oldValue !== group else { return }
            oldValue.remove(self)
            group.add(self)
        }
    }

    init(title: String, group: RadioButtonGroup) {
        self.group = group

        super.init(frame: .zero)
        self.setButtonType(.radio)
        self.title = title

        self.setContentHuggingPriority(.init(rawValue: 1000), for: .horizontal)
        group.add(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_DownArrow:
            group.selectNext()
        case kVK_UpArrow:
            group.selectPrevious()
        default:
            super.keyDown(with: event)
        }
    }

}

/// Used instead of SwiftUI Picker for correct Key View Loop handling
struct RadioButton: NSViewRepresentable {

    let title: String
    let group: RadioButtonGroup

    func makeNSView(context: Context) -> CustomRadioButton {
        CustomRadioButton(title: title, group: group)
    }

    func updateNSView(_ btn: CustomRadioButton, context: Context) {
        btn.title = title
        btn.group = group
    }

}
