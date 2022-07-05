//
//  PinnedTabsModel.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import Combine

final class PinnedTabsModel: ObservableObject {
    @Published var items: [Tab] = [] {
        didSet {
            if oldValue != items && Set(oldValue) == Set(items) {
                tabsDidReorderSubject.send(items)
            }
        }
    }

    @Published var selectedItem: Tab?

    let tabsDidReorderPublisher: AnyPublisher<[Tab], Never>

    init(collection: TabCollection) {
        tabsDidReorderPublisher = tabsDidReorderSubject.eraseToAnyPublisher()
        collection.$tabs
            .assign(to: \.items, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    private let tabsDidReorderSubject = PassthroughSubject<[Tab], Never>()
    private var cancellables = Set<AnyCancellable>()
}
