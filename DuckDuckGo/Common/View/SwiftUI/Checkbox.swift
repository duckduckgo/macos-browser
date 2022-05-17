//
//  Checkbox.swift
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

/// Used instead of SwiftUI Toggle for correct Key View Loop handling
struct Checkbox: NSViewRepresentable {

    let title: String
    @Binding var isOn: Bool

    func makeNSView(context: Context) -> NSButton {
        let delegate = ButtonDelegate { _ in
            isOn.toggle()
        }
        let btn = NSButton(checkboxWithTitle: title, target: delegate, action: #selector(ButtonDelegate.action(_:)))
        btn.state = isOn ? .on : .off
        btn.cell?.representedObject = delegate

        return btn
    }

    func updateNSView(_ btn: NSButton, context: Context) {
        btn.title = title
        btn.state = isOn ? .on : .off
        (btn.target as? ButtonDelegate)?.onClick = { _ in
            isOn.toggle()
        }
    }

}

// swiftlint:disable:next identifier_name
func Toggle(_ title: String, isOn: Binding<Bool>) -> Checkbox {
    return Checkbox(title: title, isOn: isOn)
}
