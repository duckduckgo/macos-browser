//
//  AppStateChangedPublisher.swift
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
import Combine

extension Tab {
    var stateChanged: AnyPublisher<Void, Never> {
        $content.asVoid()
            .merge(with: $favicon.asVoid())
            .merge(with: $title.asVoid())
            .eraseToAnyPublisher()
    }
}

extension TabCollectionViewModel {
    var stateChanged: AnyPublisher<Void, Never> {
        tabCollection.$tabs.nestedObjectChanges(\.stateChanged)
            .merge(with: $selectionIndex.asVoid())
            .eraseToAnyPublisher()
    }
}

extension MainWindowController {
    var stateChanged: AnyPublisher<Void, Never> {
        mainViewController.tabCollectionViewModel.stateChanged
            .merge(with: window!.publisher(for: \.frame).asVoid())
            .eraseToAnyPublisher()
    }
}

extension WindowControllersManager {
    var stateChanged: AnyPublisher<Void, Never> {
        $mainWindowControllers.nestedObjectChanges(\.stateChanged)
            .handleEvents(receiveOutput: { [unowned self] in
                self.updateIsInInitialState()
            })
            .filter { [unowned self] in !self.isInInitialState }
            .eraseToAnyPublisher()
    }
}
