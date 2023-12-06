//
//  BlockMenuItem.swift
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

import Foundation

final class BlockMenuItem: NSMenuItem {
    var block: (() -> Void)?

    convenience init(title: String, keyEquivalent: String = "", isChecked: Bool, block: (() -> Void)?) {
        self.init(title: title, action: #selector(performBlockAction(_:)), keyEquivalent: keyEquivalent)
        self.block = block
        self.target = self
        self.state = isChecked ? .on : .off
    }

    @objc func performBlockAction(_ sender: NSMenuItem) {
        block?()
    }
}
