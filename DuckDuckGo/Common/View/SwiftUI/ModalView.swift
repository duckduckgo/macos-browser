//
//  ModalView.swift
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

protocol ModalView: View {}

extension ModalView {

    @MainActor
    func show(in window: NSWindow? = nil, completion: (() -> Void)? = nil) {

        guard let window = window ?? WindowControllersManager.shared.lastKeyMainWindowController?.window else {
            assertionFailure("No parent window to display in. Displaying app-wide modal windows not implemented")
            completion?()
            return
        }

        if !window.isKeyWindow {
            window.makeKeyAndOrderFront(nil)
        }

        let sheetWindow = SheetHostingWindow(rootView: self)

        window.beginSheet(sheetWindow, completionHandler: completion.map { completion in { _ in
            completion()
        }
        })
    }

}
