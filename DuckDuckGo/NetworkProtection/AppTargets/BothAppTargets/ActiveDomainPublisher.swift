//
//  ActiveDomainPublisher.swift
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

import Combine
import Foundation

/// A convenience class for publishing the active domain
///
/// The active domain is the domain loaded in the last active tab within the last active window.
///
final class ActiveDomainPublisher {

    private let windowControllersManager: WindowControllersManager
    private var activeWindowControllerCancellable: AnyCancellable?
    private var activeTabViewModelCancellable: AnyCancellable?
    private var activeTabContentCancellable: AnyCancellable?

    @MainActor
    @Published
    private var activeWindowController: MainWindowController? {
        didSet {
            subscribeToActiveTabViewModel()
        }
    }

    @MainActor
    @Published
    private var activeTab: Tab? {
        didSet {
            subscribeToActiveTabContentChanges()
        }
    }

    init(windowControllersManager: WindowControllersManager) {
        self.windowControllersManager = windowControllersManager

        Task { @MainActor in
            subscribeToKeyWindowControllerChanges()
        }
    }

    @Published
    private(set) var activeDomain: String?

    @MainActor
    private func subscribeToKeyWindowControllerChanges() {
        activeWindowControllerCancellable = windowControllersManager
            .didChangeKeyWindowController
            .prepend(windowControllersManager.lastKeyMainWindowController)
            .assign(to: \.activeWindowController, onWeaklyHeld: self)
    }

    @MainActor
    private func subscribeToActiveTabViewModel() {
        activeTabViewModelCancellable = activeWindowController?.mainViewController.tabCollectionViewModel.$selectedTabViewModel
            .map(\.?.tab)
            .assign(to: \.activeTab, onWeaklyHeld: self)
    }

    @MainActor
    private func subscribeToActiveTabContentChanges() {
        activeTabContentCancellable = activeTab?.$content
            .map(domain(from:))
            .removeDuplicates()
            .assign(to: \.activeDomain, onWeaklyHeld: self)
    }

    private func domain(from tabContent: Tab.TabContent) -> String? {
        if case .url(let url, _, _) = tabContent {

            return url.host
        } else {
            return nil
        }
    }
}

extension ActiveDomainPublisher: Publisher {
    typealias Output = String?
    typealias Failure = Never

    func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, String? == S.Input {
        $activeDomain.subscribe(subscriber)
    }
}