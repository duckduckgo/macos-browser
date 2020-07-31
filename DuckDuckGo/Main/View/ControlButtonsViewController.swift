//
//  ControlButtonsViewController.swift
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

import Cocoa
import os.log

class ControlButtonsViewController: NSViewController {

    override func viewWillAppear() {
        super.viewWillAppear()

        addWindowButtons()
    }

    private enum ButtonConstraintsConstants {
        static let buttonWidth: CGFloat = 14
        static let buttonSpace: CGFloat = 6
    }

    var controlButtons: [NSButton]?

    private func addWindowButtons() {
        guard controlButtons == nil else { return }
        controlButtons = [NSButton]()

        guard let window = view.window else {
            os_log("MainWindowController: window is nil", log: OSLog.Category.general, type: .error)
            return
        }

        let buttonTypes: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        buttonTypes.enumerated().forEach { (index, button) in
            guard let button = NSWindow.standardWindowButton(button, for: window.styleMask) else {
                os_log("MainWindowController: Failed to get window button", log: OSLog.Category.general, type: .error)
                return
            }
            layoutWindowButton(button, index: index)
        }
    }

    private func layoutWindowButton(_ button: NSButton, index: Int) {
        view.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false

        let leadingSpace = CGFloat(index) * (ButtonConstraintsConstants.buttonWidth + ButtonConstraintsConstants.buttonSpace)
        button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leadingSpace).isActive = true
        button.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true

        controlButtons?.append(button)
    }

}
