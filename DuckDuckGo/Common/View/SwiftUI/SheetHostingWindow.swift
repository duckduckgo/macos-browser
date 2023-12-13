//
//  SheetHostingWindow.swift
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

internal class SheetHostingWindow<Content: View>: NSWindow {

    init(rootView: Content) {
        super.init(contentRect: .zero, styleMask: [.titled, .closable, .docModalWindow], backing: .buffered, defer: false)
        self.contentView = NSHostingView(rootView: rootView.legacyOnDismiss { [weak self] in
            self?.performClose(nil)
        })
    }

    override func performClose(_ sender: Any?) {
        guard let sheetParent else {
            super.performClose(sender)
            return
        }
        sheetParent.endSheet(self, returnCode: .alertFirstButtonReturn)
    }

}
