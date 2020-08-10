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
import Combine

class TabBarViewController: NSViewController {

    @IBOutlet weak var collectionView: NSCollectionView!

    private let tabCollectionViewModel: TabCollectionViewModel
    private var tabsCancelable: AnyCancellable?
    private var selectionIndexCancelable: AnyCancellable?

    required init?(coder: NSCoder) {
        fatalError("TabBarViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCollectionView()
        bindSelectionIndex()
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        addInitialTab()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        tabCollectionViewModel.tabCollection.delegate = self
    }

    @IBAction func burnButtonAction(_ sender: NSButton) {
    }

    @IBAction func addButtonAction(_ sender: NSButton) {
        tabCollectionViewModel.appendNewTab()
    }

    private func setupCollectionView() {
        let nib = NSNib(nibNamed: "TabBarViewItem", bundle: nil)
        collectionView.register(nib, forItemWithIdentifier: TabBarViewItem.identifier)

        // Register for the dropped object types we can accept.
        collectionView.registerForDraggedTypes([NSPasteboard.PasteboardType.string])
        // Enable dragging items within and into our CollectionView.
        collectionView.setDraggingSourceOperationMask(NSDragOperation.move, forLocal: false)
    }

    private func bindSelectionIndex() {
        selectionIndexCancelable = tabCollectionViewModel.$selectionIndex.sinkAsync { [weak self] _ in
            self?.reloadSelection()
        }
    }

    private func reloadSelection() {
        guard collectionView.selectionIndexPaths.first?.item != tabCollectionViewModel.selectionIndex else {
            return
        }

        guard let selectionIndex = tabCollectionViewModel.selectionIndex else {
            os_log("TabBarViewController: Selection index is nil", log: OSLog.Category.general, type: .error)
            return
        }

        let newSelectionIndexPath = IndexPath(item: selectionIndex, section: 0)

        collectionView.deselectItems(at: collectionView.selectionIndexPaths)
        collectionView.animator().selectItems(at: [newSelectionIndexPath], scrollPosition: .nearestVerticalEdge)
    }

    private func addInitialTab() {
        tabCollectionViewModel.appendNewTab()
    }

    // MARK: - Selection

    private func selectItem(at indexPath: IndexPath) {
        tabCollectionViewModel.select(at: indexPath.item)
    }

    // MARK: - Closing

    private func closeItem(at indexPath: IndexPath) {
        tabCollectionViewModel.remove(at: indexPath.item)

        if indexPath.item == 0 && tabCollectionViewModel.tabCollection.tabs.count == 0 {
            NSApplication.shared.terminate(self)
        }
    }

    // MARK: - Drag and Drop

    private var draggingIndexPaths: Set<IndexPath>?
    private var lastIndexPath: IndexPath?

    private func moveItemIfNeeded(at indexPath: IndexPath, to newIndexPath: IndexPath) {
        guard newIndexPath != lastIndexPath else {
            return
        }

        let index = indexPath.item
        let newIndex = min(newIndexPath.item, max(tabCollectionViewModel.tabCollection.tabs.count - 1, 0))
        let newIndexPath = IndexPath(item: newIndex, section: 0)

        guard index != newIndex else {
            return
        }
        lastIndexPath = newIndexPath

        tabCollectionViewModel.tabCollection.moveTab(at: index, to: newIndex)
        tabCollectionViewModel.select(at: newIndexPath.item)
    }

    // MARK: - Variable width

    func currentTabWidth() -> CGFloat {
        let numberOfItems = CGFloat(collectionView.numberOfItems(inSection: 0))
        let collectionViewWidth = collectionView.bounds.width

        if numberOfItems * TabBarViewItem.Width.large.rawValue < collectionViewWidth {
            return TabBarViewItem.Width.large.rawValue
        } else if numberOfItems * TabBarViewItem.Width.medium.rawValue < collectionViewWidth {
            return TabBarViewItem.Width.medium.rawValue
        } else {
            return TabBarViewItem.Width.small.rawValue
        }
    }

}

// swiftlint:disable compiler_protocol_init
extension TabBarViewController: TabCollectionDelegate {

    func tabCollection(_ tabCollection: TabCollection, didAppend tab: Tab) {
        let lastIndex = tabCollectionViewModel.tabCollection.tabs.count - 1
        let lastIndexPath = IndexPath(item: lastIndex, section: 0)
        let lastIndexPathSet = Set(arrayLiteral: lastIndexPath)
        collectionView.animator().insertItems(at: lastIndexPathSet)
    }

    func tabCollection(_ tabCollection: TabCollection, didInsert tab: Tab, at index: Int) {
        let indexPath = IndexPath(item: index, section: 0)
        let indexPathSet = Set(arrayLiteral: indexPath)
        collectionView.animator().insertItems(at: indexPathSet)
    }

    func tabCollection(_ tabCollection: TabCollection, didRemoveTabAt index: Int) {
        let indexPath = IndexPath(item: index, section: 0)
        let indexPathSet = Set(arrayLiteral: indexPath)
        collectionView.animator().deleteItems(at: indexPathSet)
    }

    func tabCollection(_ tabCollection: TabCollection, didMoveTabAt index: Int, to newIndex: Int) {
        let indexPath = IndexPath(item: index, section: 0)
        let newIndexPath = IndexPath(item: newIndex, section: 0)
        collectionView.animator().moveItem(at: indexPath, to: newIndexPath)
    }

}
// swiftlint:enable compiler_protocol_init

extension TabBarViewController: NSCollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: NSCollectionView,
                        layout collectionViewLayout: NSCollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> NSSize {
        return NSSize(width: self.currentTabWidth(), height: TabBarViewItem.Height.standard.rawValue)
    }

}

extension TabBarViewController: NSCollectionViewDataSource {
    
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return tabCollectionViewModel.tabCollection.tabs.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: TabBarViewItem.identifier, for: indexPath)
        guard let tabBarViewItem = item as? TabBarViewItem else {
            os_log("", log: OSLog.Category.general, type: .error)
            return item
        }
        
        guard let tabViewModel = tabCollectionViewModel.tabViewModel(at: indexPath.item) else {
            tabBarViewItem.clear()
            return tabBarViewItem
        }

        tabBarViewItem.delegate = self
        tabBarViewItem.bind(tabViewModel: tabViewModel)
        return tabBarViewItem
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

    func collectionView(_ collectionView: NSCollectionView,
                        canDragItemsAt indexPaths: Set<IndexPath>,
                        with event: NSEvent) -> Bool {
        return true
    }

    func collectionView(_ collectionView: NSCollectionView,
                        pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        if let url = tabCollectionViewModel.tabCollection.tabs[indexPath.item].url {
            return url.absoluteString as NSString
        } else {
            return "" as NSString
        }
    }

    func collectionView(_ collectionView: NSCollectionView,
                        draggingSession session: NSDraggingSession,
                        willBeginAt screenPoint: NSPoint,
                        forItemsAt indexPaths: Set<IndexPath>) {
        session.animatesToStartingPositionsOnCancelOrFail = false
        draggingIndexPaths = indexPaths
    }

    func collectionView(_ collectionView: NSCollectionView,
                        draggingSession session: NSDraggingSession,
                        endedAt screenPoint: NSPoint,
                        dragOperation operation: NSDragOperation) {
        draggingIndexPaths = nil
        lastIndexPath = nil
    }

    func collectionView(_ collectionView: NSCollectionView,
                        validateDrop draggingInfo: NSDraggingInfo,
                        proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
                        dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        guard let draggingIndexPaths = draggingIndexPaths else {
            os_log("TabBarViewController: Dragging index paths is nil", log: OSLog.Category.general, type: .error)
            return .copy
        }

        guard let indexPath = draggingIndexPaths.first, draggingIndexPaths.count == 1 else {
            os_log("TabBarViewController: More than 1 dragging index path", log: OSLog.Category.general, type: .error)
            return .move
        }

        let newIndexPath = proposedDropIndexPath.pointee as IndexPath
        if let lastIndexPath = lastIndexPath {
            moveItemIfNeeded(at: lastIndexPath, to: newIndexPath)
        } else {
            moveItemIfNeeded(at: indexPath, to: newIndexPath)
        }

        proposedDropOperation.pointee = .before
        return .move
    }

    func collectionView(_ collectionView: NSCollectionView,
                        acceptDrop draggingInfo: NSDraggingInfo,
                        indexPath: IndexPath,
                        dropOperation: NSCollectionView.DropOperation) -> Bool {
        guard let draggingIndexPaths = draggingIndexPaths else {
            os_log("TabBarViewController: Dragging index paths is nil", log: OSLog.Category.general, type: .error)
            return false
        }

        guard draggingIndexPaths.count == 1 else {
            os_log("TabBarViewController: More than 1 item selected", log: OSLog.Category.general, type: .error)
            return false
        }

        return true
    }

}

extension TabBarViewController: TabBarViewItemDelegate {

    func tabBarViewItemDidCloseAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            os_log("TabBarViewController: Failed to get indexPath", log: OSLog.Category.general, type: .error)
            return
        }

        closeItem(at: indexPath)
    }

}
