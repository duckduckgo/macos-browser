//
//  TabPreviewEventsHandler.swift
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

import Foundation
import Combine

final class TabPreviewEventsHandler {
    private let unpinnedTabsMouseEnteredAndExitedPublisher = PassthroughSubject<TabPreviewEvent, Never>()
    private var cancellables: Set<AnyCancellable> = []

    private let pinnedTabsMouseExitedPublisher: AnyPublisher<TabPreviewEvent, Never>
    private let pinnedTabsMouseEnteredPublisher: AnyPublisher<TabPreviewEvent, Never>

    var eventPublisher: AnyPublisher<TabPreviewEvent, Never> {
        Publishers.Merge3(pinnedTabsMouseExitedPublisher, pinnedTabsMouseEnteredPublisher, unpinnedTabsMouseEnteredAndExitedPublisher).eraseToAnyPublisher()
    }

    init(
        pinnedTabHoveredIndexPublisher: AnyPublisher<Int?, Never>,
        pinnedTabMouseMovingPublisher: AnyPublisher<Void, Never>
    ) {
        // Instead of showing the tab preview when the mouse enter the tracking area we want to show when the mouse moves within the area.
        // The reason is that when the mouse is hovered on a Tab and we exit full screen, we don't want to show the preview again.
        // We want to show it only if the user moves the mouse as per Safari behaviour.

        pinnedTabsMouseExitedPublisher = pinnedTabHoveredIndexPublisher
            .dropFirst()
            .removeDuplicates()
            .filter { index in
                index == nil
            }
            .map { _ -> TabPreviewEvent in
                TabPreviewEvent.hide(allowQuickRedisplay: true, withDelay: false)
            }
            .eraseToAnyPublisher()

        pinnedTabsMouseEnteredPublisher = pinnedTabMouseMovingPublisher
            .dropFirst()
            .withLatestFrom(pinnedTabHoveredIndexPublisher)
            .compactMap { index in
                guard let index else { return nil }
                return TabPreviewEvent.show(.pinned(index))
            }
            .eraseToAnyPublisher()
    }

    func unpinnedTabMouseExited() {
        unpinnedTabsMouseEnteredAndExitedPublisher.send(.hide(allowQuickRedisplay: true, withDelay: true))
    }

    func unpinnedTabMouseEntered(tabBarViewItem: TabBarViewItem) {
        unpinnedTabsMouseEnteredAndExitedPublisher.send(.show(.unpinned(tabBarViewItem)))
    }

}

extension TabPreviewEventsHandler {

    enum TabPreviewEvent {
        enum Tab {
            case pinned(Int)
            case unpinned(TabBarViewItem)
        }
        case show(Tab)
        case hide(allowQuickRedisplay: Bool, withDelay: Bool)
    }

}
