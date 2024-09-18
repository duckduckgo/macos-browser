//
//  KeyEquivalentView.swift
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

/// Used to catch `performKeyEquivalent:` events in View Controllers
final class KeyEquivalentView: NSView {
    private let keyEquivalents: [NSEvent.KeyEquivalent: (NSEvent) -> Bool]

    init(keyEquivalents: [NSEvent.KeyEquivalent: (NSEvent) -> Bool]) {
        self.keyEquivalents = keyEquivalents
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("\(type(of: self)): Bad initializer")
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let keyEquivalent = event.keyEquivalent,
              let handler = keyEquivalents[keyEquivalent] else { return false }
        return handler(event)
    }
}
