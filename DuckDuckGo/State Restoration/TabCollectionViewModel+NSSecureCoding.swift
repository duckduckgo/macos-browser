//
//  TabCollectionViewModel+NSSecureCoding.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

extension TabCollectionViewModel: NSSecureCoding {
    private enum NSSecureCodingKeys {
        static let tabCollection = "tabs"
        static let selectionIndex = "idx"
        static let isPinned = "pinned"
    }

    static var supportsSecureCoding: Bool { true }

    convenience init?(coder: NSCoder) {
        guard let tabCollection = coder.decodeObject(of: TabCollection.self, forKey: NSSecureCodingKeys.tabCollection),
              !tabCollection.tabs.isEmpty
        else {
            return nil
        }
        let isPinned = coder.decodeIfPresent(at: NSSecureCodingKeys.isPinned) ?? false
        let index = coder.decodeIfPresent(at: NSSecureCodingKeys.selectionIndex) ?? 0
        let selectionIndex: SelectedTabIndex = isPinned ? .pinned(index) : .regular(index)
        self.init(tabCollection: tabCollection, selectionIndex: selectionIndex)
    }

    func encode(with coder: NSCoder) {
        if let index = selectionIndex {
            coder.encode(index.index, forKey: NSSecureCodingKeys.selectionIndex)
            coder.encode(index.isPinnedTab, forKey: NSSecureCodingKeys.isPinned)
        }
        coder.encode(tabCollection, forKey: NSSecureCodingKeys.tabCollection)
    }

}
