//
//  TabDragAndDropManager.swift
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

/// Responsible for handling drag and drop of tabs between windows
@MainActor
final class TabDragAndDropManager {

    static let shared = TabDragAndDropManager()

    private init() { }

    struct Unit {
        weak var tabCollectionViewModel: TabCollectionViewModel?
        var index: Int
    }

    private(set) var sourceUnit: Unit?
    private(set) var destinationUnit: Unit?

    func setSource(tabCollectionViewModel: TabCollectionViewModel, index: Int) {
        sourceUnit = .init(tabCollectionViewModel: tabCollectionViewModel, index: index)
    }

    func setDestination(tabCollectionViewModel: TabCollectionViewModel, index: Int) {
        // ignore dragged objects from other apps
        guard sourceUnit != nil else { return }
        destinationUnit = .init(tabCollectionViewModel: tabCollectionViewModel, index: index)
    }

    func clearDestination() {
        destinationUnit = nil
    }

    @discardableResult
    func performDragAndDropIfNeeded() -> Bool {
        if let sourceUnit = sourceUnit,
           let destinationUnit = destinationUnit,
           sourceUnit.tabCollectionViewModel !== destinationUnit.tabCollectionViewModel,
           sourceUnit.tabCollectionViewModel?.isBurner == destinationUnit.tabCollectionViewModel?.isBurner {

            performDragAndDrop(from: sourceUnit, to: destinationUnit)
            return true
        }

        return false
    }

    private func performDragAndDrop(from sourceUnit: Unit, to destinationUnit: Unit) {
        guard let sourceTabCollectionViewModel = sourceUnit.tabCollectionViewModel,
              let destinationTabCollectionViewModel = destinationUnit.tabCollectionViewModel
        else {
            assertionFailure("TabDragAndDropManager: Missing data to perform drag and drop")
            return
        }

        let newIndex = min(destinationUnit.index, destinationTabCollectionViewModel.tabCollection.tabs.count)
        sourceTabCollectionViewModel.moveTab(at: sourceUnit.index, to: destinationTabCollectionViewModel, at: newIndex)
    }

    func clear() {
        sourceUnit = nil
        destinationUnit = nil
    }

}
