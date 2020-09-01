//
//  NSViewExtension.swift
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

extension NSView {

    func addAndLayout(_ subView: NSView) {
        subView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subView)

        subView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        subView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        subView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        subView.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
    }

    func makeMeFirstResponder() {
        guard let window = window else {
            os_log("%s: Window not available", log: OSLog.Category.general, type: .error, className)
            return
        }

        window.makeFirstResponder(self)
    }

}
