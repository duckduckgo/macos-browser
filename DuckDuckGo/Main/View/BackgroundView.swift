//
//  BackgroundColorView.swift
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

internal class BackgroundColorView: NSView {

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        commonInit()
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        commonInit()
    }

    @IBInspectable public var backgroundColor: NSColor? = NSColor.clear {
        didSet {
            layer?.backgroundColor = backgroundColor?.cgColor
        }
    }

    func commonInit() {
        self.wantsLayer = true
    }
}
