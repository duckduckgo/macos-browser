//
//  NSWindow+Toast.swift
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

extension NSWindow {

    @available(macOS, deprecated: 10.14, message: "Temporary solution while waiting for better design.")
    func toast(_ message: String) {
        let text = NSTextField(labelWithString: message)
        text.frame.origin = CGPoint(x: 5, y: 3)
        contentView?.addSubview(text)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            text.removeFromSuperview()
        }
    }

}
