//
//  SavePanelAccessoryView.swift
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

final class SavePanelAccessoryView: NSView {
    let fileTypesPopup: NSPopUpButton

    init() {
        self.fileTypesPopup = NSPopUpButton(frame: NSRect(x: 115, y: 20, width: 251, height: 25))

        super.init(frame: NSRect(x: 0, y: 0, width: 480, height: 67))

        self.addSubview(fileTypesPopup)
        fileTypesPopup.removeAllItems()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
