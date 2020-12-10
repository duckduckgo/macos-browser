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

    enum CollectionViewHorizontalSpace: CGFloat {
        case withScrollButtons = 112
        case withoutScrollButtons = 80
    }

    @IBOutlet weak var collectionView: TabBarCollectionView!
    @IBOutlet weak var scrollView: TabBarScrollView!
    @IBOutlet weak var scrollViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var rightScrollButton: MouseOverButton!
    @IBOutlet weak var leftScrollButton: MouseOverButton!
    @IBOutlet weak var rightShadowImageView: NSImageView!
    @IBOutlet weak var leftShadowImageView: NSImageView!
    @IBOutlet weak var windowDraggingViewLeadingConstraint: NSLayoutConstraint!

    private let tabCollectionViewModel: TabCollectionViewModel
    lazy private var fireViewModel = FireViewModel()

    private var tabsCancellable: AnyCancellable?
    private var selectionIndexCancellable: AnyCancellable?

    required init?(coder: NSCoder) {
        fatalError("TabBarViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateScrollElasticity()
        receiveScrollNotifications()
        subscribeToSelectionIndex()
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        updateWindowDraggingArea()
        tabCollectionViewModel.delegate = self

        reloadSelection()
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        updateTabMode(for: collectionView.numberOfItems(inSection: 0))
        updateWindowDraggingArea()
        collectionView.invalidateLayout()
    }

    @IBAction func burnButtonAction(_ sender: NSButton) {
        let response = NSAlert.burnButtonAlert.runModal()
        if response == NSApplication.ModalResponse.alertFirstButtonReturn {
            WindowsManager.closeWindows(except: view.window)
            fireViewModel.fire.burnAll(tabCollectionViewModel: tabCollectionViewModel)
        }
    }

    @IBAction func addButtonAction(_ sender: NSButton) {
        tabCollectionViewModel.appendNewTab()
    }

    @IBAction func rightScrollButtonAction(_ sender: NSButton) {
        collectionView.scrollToEnd()
    }

    @IBAction func leftScrollButtonAction(_ sender: NSButton) {
        collectionView.scrollToBeginning()
    }

    private func subscribeToSelectionIndex() {
        selectionIndexCancellable = tabCollectionViewModel.$selectionIndex.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.reloadSelection()
        }
    }

    private func reloadSelection() {
        guard collectionView.selectionIndexPaths.first?.item != tabCollectionViewModel.selectionIndex else {
            return
        }

        guard let selectionIndex = tabCollectionViewModel.selectionIndex else {
            os_log("TabBarViewController: Selection index is nil", type: .error)
            return
        }
        
        if collectionView.selectionIndexPaths.count > 0 {
            collectionView.clearSelection()
        }

        let newSelectionIndexPath = IndexPath(item: selectionIndex)
        if tabMode == .divided {
            collectionView.animator().selectItems(at: [newSelectionIndexPath], scrollPosition: .centeredHorizontally)
        } else {
            collectionView.selectItems(at: [newSelectionIndexPath], scrollPosition: .centeredHorizontally)
        }
    }

    private func closeWindowIfNeeded() {
        if tabCollectionViewModel.tabCollection.tabs.isEmpty {
            guard let window = view.window else {
                os_log("AddressBarTextField: Window not available", type: .error)
                return
            }
            window.close()
        }
    }

    // MARK: - Window Dragging

    private func updateWindowDraggingArea() {
        let selectedWidth = currentTabWidth(selected: true)
        let restOfTabsWidth = CGFloat(max(collectionView.numberOfItems(inSection: 0) - 1, 0)) * currentTabWidth()
        let totalWidth = selectedWidth + restOfTabsWidth
        let leadingSpace = min(totalWidth, scrollView.frame.size.width)
        windowDraggingViewLeadingConstraint.constant = leadingSpace
    }

    // MARK: - Closing

    private func closeItem(at indexPath: IndexPath) {
        tabCollectionViewModel.remove(at: indexPath.item)
    }

    // MARK: - Drag and Drop

    private var draggingIndexPaths: Set<IndexPath>?
    private var draggingOverIndexPath: IndexPath?

    private func moveItemIfNeeded(at indexPath: IndexPath, to newIndexPath: IndexPath) {
        guard newIndexPath != draggingOverIndexPath else { return }

        let index = indexPath.item
        let newIndex = min(newIndexPath.item, max(tabCollectionViewModel.tabCollection.tabs.count - 1, 0))
        let newIndexPath = IndexPath(item: newIndex)

        guard index != newIndex else { return }
        draggingOverIndexPath = newIndexPath

        tabCollectionViewModel.moveTab(at: index, to: newIndex)
    }

    // MARK: - Tab Width

    private enum TabMode {
        case divided
        case overflow
    }

    private var tabMode = TabMode.divided {
        didSet {
            if oldValue != tabMode {
                updateScrollElasticity()
                updateScrollButtons()
                updateWindowDraggingArea()
                collectionView.invalidateLayout()
            }
        }
    }

    private func updateTabMode(for numberOfItems: Int? = nil) {
        let items = CGFloat(numberOfItems ?? collectionView.numberOfItems(inSection: 0))
        let tabsWidth = scrollView.bounds.width

        if max(0, (items - 1)) * TabBarViewItem.Width.minimum.rawValue + TabBarViewItem.Width.minimumSelected.rawValue < tabsWidth {
            tabMode = .divided
        } else {
            tabMode = .overflow
        }
    }

    private func currentTabWidth(selected: Bool = false) -> CGFloat {
        let numberOfItems = CGFloat(collectionView.numberOfItems(inSection: 0))
        let tabsWidth = scrollView.bounds.width
        let minimumWidth = selected ? TabBarViewItem.Width.minimumSelected.rawValue : TabBarViewItem.Width.minimum.rawValue

        if tabMode == .divided {
            var dividedWidth = tabsWidth / numberOfItems
            // If tabs are shorter than minimumSelected, then the selected tab takes more space
            if dividedWidth < TabBarViewItem.Width.minimumSelected.rawValue {
                dividedWidth = (tabsWidth - TabBarViewItem.Width.minimumSelected.rawValue) / (numberOfItems - 1)
            }
            return min(TabBarViewItem.Width.maximum.rawValue, max(minimumWidth, dividedWidth))
        } else {
            return minimumWidth
        }
    }

    private func updateScrollElasticity() {
        scrollView.horizontalScrollElasticity = tabMode == .divided ? .none : .allowed
    }

    // MARK: - Scroll Buttons

    private func receiveScrollNotifications() {
        scrollView.contentView.postsBoundsChangedNotifications = true

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(scrollViewBoundsDidChange(_:)),
                                               name: NSView.boundsDidChangeNotification,
                                               object: scrollView.contentView)
    }

    @objc private func scrollViewBoundsDidChange(_ sender: Any) {
        let clipView = scrollView.contentView
        rightScrollButton.isEnabled = clipView.bounds.origin.x + clipView.bounds.size.width < collectionView.bounds.size.width
        leftScrollButton.isEnabled = clipView.bounds.origin.x > 0
    }

    private func updateScrollButtons() {
        let horizontalSpace = tabMode == .divided ?
            CollectionViewHorizontalSpace.withoutScrollButtons.rawValue :
            CollectionViewHorizontalSpace.withScrollButtons.rawValue
        scrollViewLeadingConstraint.constant = horizontalSpace
        scrollViewTrailingConstraint.constant = horizontalSpace

        let scrollViewsAreHidden = tabMode == .divided
        rightScrollButton.isHidden = scrollViewsAreHidden
        leftScrollButton.isHidden = scrollViewsAreHidden
        rightShadowImageView.isHidden = scrollViewsAreHidden
        leftShadowImageView.isHidden = scrollViewsAreHidden
    }

}

extension TabBarViewController: TabCollectionViewModelDelegate {

    func tabCollectionViewModelDidAppend(_ tabCollectionViewModel: TabCollectionViewModel) {
        appendToCollectionView(selected: false)
    }

    func tabCollectionViewModelDidAppendAndSelect(_ tabCollectionViewModel: TabCollectionViewModel) {
        appendToCollectionView(selected: true)
    }

    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel, didAppendAtMultipleAndSelectAt index: Int) {
        reloadCollectionView(selectionIndex: index)
    }

    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel, didInsertAndSelectAt index: Int) {
        let indexPath = IndexPath(item: index)
        let indexPathSet = Set(arrayLiteral: indexPath)
        collectionView.animator().insertItems(at: indexPathSet)
        collectionView.selectItems(at: indexPathSet, scrollPosition: .centeredHorizontally)

        updateTabMode()
        updateWindowDraggingArea()
    }

    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel,
                                didRemoveTabAt removedIndex: Int,
                                andSelectTabAt selectionIndex: Int) {
        let removedIndexPath = IndexPath(item: removedIndex)
        let removedIndexPathSet = Set(arrayLiteral: removedIndexPath)
        let selectionIndexPath = IndexPath(item: selectionIndex)
        let selectionIndexPathSet = Set(arrayLiteral: selectionIndexPath)

        collectionView.animator().performBatchUpdates {
            collectionView.animator().deleteItems(at: removedIndexPathSet)
            collectionView.animator().selectItems(at: selectionIndexPathSet, scrollPosition: .centeredHorizontally)
        } completionHandler: { [weak self] _ in
            self?.updateTabMode()
            self?.updateWindowDraggingArea()
        }
    }

    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel,
                                didRemoveAllExcept exceptionIndex: Int?,
                                andSelectAt selectionIndex: Int?) {
        reloadCollectionView(selectionIndex: selectionIndex)
    }

    func tabCollectionViewModelDidRemoveAllAndAppend(_ tabCollectionViewModel: TabCollectionViewModel) {
        reloadCollectionView(selectionIndex: 0)
    }

    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel, didMoveTabAt index: Int, to newIndex: Int) {
        let indexPath = IndexPath(item: index)
        let newIndexPath = IndexPath(item: newIndex)
        collectionView.animator().moveItem(at: indexPath, to: newIndexPath)

        updateTabMode()
    }

    private func appendToCollectionView(selected: Bool) {
        let lastIndex = max(0, tabCollectionViewModel.tabCollection.tabs.count - 1)
        let lastIndexPathSet = Set(arrayLiteral: IndexPath(item: lastIndex))

        updateTabMode(for: collectionView.numberOfItems(inSection: 0) + 1)

        collectionView.clearSelection()
        if tabMode == .divided {
            collectionView.animator().insertItems(at: lastIndexPathSet)
            if selected {
                collectionView.selectItems(at: lastIndexPathSet, scrollPosition: .centeredHorizontally)
            }
        } else {
            collectionView.insertItems(at: lastIndexPathSet)
            if selected {
                collectionView.selectItems(at: lastIndexPathSet, scrollPosition: .centeredHorizontally)
            }
            // Old frameworks are like old people. They need a special treatment
            collectionView.scrollToEnd { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.collectionView.scrollToEnd()
                }
            }
        }
        updateWindowDraggingArea()
    }

    private func reloadCollectionView(selectionIndex: Int? = nil) {
        collectionView.animator().performBatchUpdates {
            collectionView.animator().reloadData()
        } completionHandler: { [weak self] _ in
            self?.updateTabMode()
        }

        if let selectionIndex = selectionIndex {
            let selectionIndexPath = IndexPath(arrayLiteral: selectionIndex)
            let selectionIndexPathSet = Set(arrayLiteral: selectionIndexPath)
            collectionView.selectItems(at: selectionIndexPathSet, scrollPosition: .centeredHorizontally)
        }
    }
}

extension TabBarViewController: NSCollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: NSCollectionView,
                        layout collectionViewLayout: NSCollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> NSSize {
        var isItemSelected = tabCollectionViewModel.selectionIndex == indexPath.item

        if let draggingOverIndexPath = draggingOverIndexPath {
            // Drag&drop in progress - the empty space is equal to the selected tab width
            isItemSelected = draggingOverIndexPath == indexPath
        }

        return NSSize(width: self.currentTabWidth(selected: isItemSelected), height: TabBarViewItem.Height.standard.rawValue)
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
            os_log("TabBarViewController: Failed to get reusable TabBarViewItem instance", type: .error)
            return item
        }
        
        guard let tabViewModel = tabCollectionViewModel.tabViewModel(at: indexPath.item) else {
            tabBarViewItem.clear()
            return tabBarViewItem
        }

        tabBarViewItem.delegate = self
        tabBarViewItem.subscribe(to: tabViewModel)
        return tabBarViewItem
    }
    
}

extension TabBarViewController: NSCollectionViewDelegate {

    func collectionView(_ collectionView: NSCollectionView,
                        didChangeItemsAt indexPaths: Set<IndexPath>,
                        to highlightState: NSCollectionViewItem.HighlightState) {
        guard indexPaths.count == 1, let indexPath = indexPaths.first else {
            os_log("TabBarViewController: More than 1 item highlighted", type: .error)
            return
        }

        if highlightState == .forSelection {
            self.collectionView.clearSelection()
            tabCollectionViewModel.select(at: indexPath.item)

            // Poor old NSCollectionView
            DispatchQueue.main.async {
                self.collectionView.scrollToSelected()
            }
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
            return url as NSURL
        } else {
            return URL.emptyPage as NSURL
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
        draggingOverIndexPath = nil
    }

    func collectionView(_ collectionView: NSCollectionView,
                        validateDrop draggingInfo: NSDraggingInfo,
                        proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
                        dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        guard let draggingIndexPaths = draggingIndexPaths else {
            os_log("TabBarViewController: Dragging index paths is nil", type: .error)
            return .copy
        }

        guard let indexPath = draggingIndexPaths.first, draggingIndexPaths.count == 1 else {
            os_log("TabBarViewController: More than 1 dragging index path", type: .error)
            return .move
        }

        let newIndexPath = proposedDropIndexPath.pointee as IndexPath
        if let draggingOverIndexPath = draggingOverIndexPath {
            moveItemIfNeeded(at: draggingOverIndexPath, to: newIndexPath)
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
            os_log("TabBarViewController: Dragging index paths is nil", type: .error)
            return false
        }

        guard draggingIndexPaths.count == 1 else {
            os_log("TabBarViewController: More than 1 item selected", type: .error)
            return false
        }

        return true
    }

}

extension TabBarViewController: TabBarViewItemDelegate {

    func tabBarViewItemDuplicateAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            os_log("TabBarViewController: Failed to get indexPath", type: .error)
            return
        }

        collectionView.clearSelection()
        tabCollectionViewModel.duplicateTab(at: indexPath.item)
    }

    func tabBarViewItemCloseAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            os_log("TabBarViewController: Failed to get indexPath", type: .error)
            return
        }

        closeItem(at: indexPath)
    }

    func tabBarViewItemCloseOtherAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            os_log("TabBarViewController: Failed to get indexPath", type: .error)
            return
        }

        tabCollectionViewModel.removeAllTabs(except: indexPath.item)
    }

}

fileprivate extension NSAlert {

    static var burnButtonAlert: NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.burnAlertMessageText
        alert.informativeText = UserText.burtAlertInformativeText
        alert.alertStyle = .warning
        alert.icon = NSImage(named: "BurnAlert")
        alert.addButton(withTitle: UserText.burn)
        alert.addButton(withTitle: UserText.cancel)
        return alert
    }

}
