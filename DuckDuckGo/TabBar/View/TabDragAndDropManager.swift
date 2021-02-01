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
import os.log

/// Responsible for handling drag and drop of tabs between windows
final class TabDragAndDropManager {

    static let shared = TabDragAndDropManager()

    private init() { }

    private typealias Unit = (tabCollectionViewModel: TabCollectionViewModel, indexPath: IndexPath)

    private var sourceUnit: Unit?
    private var destinationUnit: Unit?
    private(set) var isDropRequested: Bool = false

    func setSource(tabCollectionViewModel: TabCollectionViewModel, indexPath: IndexPath) {
        sourceUnit = (tabCollectionViewModel, indexPath)
    }

    func setDestination(tabCollectionViewModel: TabCollectionViewModel, indexPath: IndexPath) {
        isDropRequested = true
        destinationUnit = (tabCollectionViewModel, indexPath)
    }

    func performDragAndDropIfNeeded() -> Bool {
        if isDropRequested {
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
              let tab = sourceUnit.tabCollectionViewModel.tabViewModel(at: sourceUnit.indexPath.item)?.tab else {
            os_log("TabDragAndDropManager: Missing data to perform drag and drop", type: .error)
            return
        }
        let newIndexPath = min(destinationUnit.indexPath.item + 1, destinationUnit.tabCollectionViewModel.tabCollection.tabs.count)

        sourceUnit.tabCollectionViewModel.remove(at: sourceUnit.indexPath.item)
        destinationUnit.tabCollectionViewModel.insert(tab: tab, at: newIndexPath)
    }

    func clear() {
        sourceUnit = nil
        destinationUnit = nil
        isDropRequested = false
    }

}
