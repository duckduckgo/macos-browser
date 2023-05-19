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
final class TabDragAndDropManager {

    static let shared = TabDragAndDropManager()

    private init() { }

    private struct Unit {
        weak var tabCollectionViewModel: TabCollectionViewModel?
        var indexPath: IndexPath
    }

    private var sourceUnit: Unit?
    private var destinationUnit: Unit?

    func setSource(tabCollectionViewModel: TabCollectionViewModel, indexPath: IndexPath) {
        sourceUnit = .init(tabCollectionViewModel: tabCollectionViewModel, indexPath: indexPath)
    }

    func setDestination(tabCollectionViewModel: TabCollectionViewModel, indexPath: IndexPath) {
        // ignore dragged objects from other apps
        guard sourceUnit != nil else { return }
        destinationUnit = .init(tabCollectionViewModel: tabCollectionViewModel, indexPath: indexPath)
    }

    func clearDestination() {
        destinationUnit = nil
    }

    func performDragAndDropIfNeeded() -> Bool {
        if destinationUnit != nil {
            performDragAndDrop()
            clear()
            return true
        } else {
            clear()
            return false
        }
    }

    private func performDragAndDrop() {
        guard let sourceUnit = sourceUnit, let destinationUnit = destinationUnit,
              let sourceTabCollectionViewModel = sourceUnit.tabCollectionViewModel,
              let destinationTabCollectionViewModel = destinationUnit.tabCollectionViewModel
        else {
            assertionFailure("TabDragAndDropManager: Missing data to perform drag and drop")
            return
        }

        let newIndex = min(destinationUnit.indexPath.item + 1, destinationTabCollectionViewModel.tabCollection.tabs.count)
        sourceTabCollectionViewModel.moveTab(at: sourceUnit.indexPath.item, to: destinationTabCollectionViewModel, at: newIndex)
    }

    private func clear() {
        sourceUnit = nil
        destinationUnit = nil
    }

}
