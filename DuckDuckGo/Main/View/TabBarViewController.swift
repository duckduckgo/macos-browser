//
//  TabBarViewController.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

import Cocoa
import os.log

class TabBarViewController: NSViewController {

    @IBOutlet weak var collectionView: NSCollectionView!

    //todo remove
    var items = ["Test 1", "Test 2", "Test 3", "Test 4", "Test 5", "Test 6", "Test 7", "Test 8"]

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCollectionView()
    }

    private func setupCollectionView() {
        let nib = NSNib(nibNamed: "TabBarViewItem", bundle: nil)
        collectionView.register(nib, forItemWithIdentifier: TabBarViewItem.identifier)

        // Register for the dropped object types we can accept.
        collectionView.registerForDraggedTypes([NSPasteboard.PasteboardType.string])
        // Enable dragging items within and into our CollectionView.
        collectionView.setDraggingSourceOperationMask(NSDragOperation.every, forLocal: false)
    }

    @IBAction func burnButtonAction(_ sender: NSButton) {
    }

    @IBAction func addButtonAction(_ sender: NSButton) {
    }

    // MARK: - Selection

    private func selectItem(at indexPath: IndexPath) {
        collectionView.deselectAll(self)
        collectionView.selectItems(at: [indexPath], scrollPosition: .nearestHorizontalEdge)
    }

    // MARK: - Drag and Drop

    private var draggingIndexPaths: Set<IndexPath>?
    private var draggingSession: NSDraggingSession?
    private var lastIndexPath: IndexPath?

    private func moveItemIfNeeded(at indexPath: IndexPath, to newIndexPath: IndexPath) {
        guard newIndexPath != lastIndexPath else {
            return
        }

        let index = indexPath.item
        let newIndex = newIndexPath.item

        guard index != newIndex else {
            return
        }

        let adjustedNewIndex = index < newIndex ? newIndex - 1 : newIndex
        let item = items[index]

        lastIndexPath = newIndexPath

        items.remove(at: index)
        items.insert(item, at: adjustedNewIndex)
        collectionView.animator().moveItem(at: indexPath, to: newIndexPath)
    }
    
}

extension TabBarViewController: NSCollectionViewDataSource {
    
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: TabBarViewItem.identifier, for: indexPath)
        guard let tabBarViewItem = item as? TabBarViewItem else {
            os_log("", log: OSLog.Category.general, type: .error)
            return item
        }

        tabBarViewItem.titleTextField.stringValue = items[indexPath.item]
        tabBarViewItem.faviconImageView.image = NSImage(named: "NSTouchBarSearchTemplate")
        //todo
//        tabBarViewItem.display()
        return item
    }
    
}

extension TabBarViewController: NSCollectionViewDelegate {

    func collectionView(_ collectionView: NSCollectionView,
                        didChangeItemsAt indexPaths: Set<IndexPath>,
                        to highlightState: NSCollectionViewItem.HighlightState) {
        guard indexPaths.count == 1, let indexPath = indexPaths.first else {
            os_log("TabBarViewController: More than 1 item highlighted", log: OSLog.Category.general, type: .error)
            return
        }

        if highlightState == .forSelection {
            selectItem(at: indexPath)
        }
    }

    func collectionView(_ collectionView: NSCollectionView, canDragItemsAt indexPaths: Set<IndexPath>, with event: NSEvent) -> Bool {
        return true
    }

    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        return items[indexPath.item] as NSString
    }

    func collectionView(_ collectionView: NSCollectionView,
                        draggingSession session: NSDraggingSession,
                        willBeginAt screenPoint: NSPoint,
                        forItemsAt indexPaths: Set<IndexPath>) {
        draggingSession = session
        draggingIndexPaths = indexPaths
    }

    func collectionView(_ collectionView: NSCollectionView,
                        draggingSession session: NSDraggingSession,
                        endedAt screenPoint: NSPoint,
                        dragOperation operation: NSDragOperation) {
        draggingIndexPaths = nil
        draggingSession = nil
        lastIndexPath = nil
    }

    func collectionView(_ collectionView: NSCollectionView,
                        validateDrop draggingInfo: NSDraggingInfo,
                        proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
                        dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        guard let draggingIndexPaths = draggingIndexPaths else {
            return .copy
        }

        guard let indexPath = draggingIndexPaths.first, draggingIndexPaths.count == 1 else {
            return .move
        }
        let newIndexPath = proposedDropIndexPath.pointee as IndexPath

        if let lastIndexPath = lastIndexPath {
            moveItemIfNeeded(at: lastIndexPath, to: newIndexPath)
        } else {
            moveItemIfNeeded(at: indexPath, to: newIndexPath)
        }

        return .move
    }

    func collectionView(_ collectionView: NSCollectionView,
                        acceptDrop draggingInfo: NSDraggingInfo,
                        indexPath: IndexPath,
                        dropOperation: NSCollectionView.DropOperation) -> Bool {
        guard let draggingIndexPaths = draggingIndexPaths else {
            return false
        }

        guard draggingIndexPaths.count == 1 else {
            os_log("TabBarViewController: More than 1 item selected", log: OSLog.Category.general, type: .error)
            return false
        }

        return true
    }

}
