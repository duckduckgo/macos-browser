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
import Lottie

// swiftlint:disable file_length
// swiftlint:disable type_body_length
final class TabBarViewController: NSViewController {

    enum HorizontalSpace: CGFloat {
        case leadingStackViewPadding = 76
        case button = 28
        case buttonPadding = 4
    }

    @IBOutlet weak var collectionView: TabBarCollectionView!
    @IBOutlet weak var scrollView: TabBarScrollView!
    @IBOutlet weak var leadingStackViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var rightScrollButton: MouseOverButton!
    @IBOutlet weak var leftScrollButton: MouseOverButton!
    @IBOutlet weak var rightShadowImageView: NSImageView!
    @IBOutlet weak var leftShadowImageView: NSImageView!
    @IBOutlet weak var plusButton: MouseOverButton!
    @IBOutlet weak var burnButton: BurnButton!
    @IBOutlet weak var draggingSpace: NSView!
    @IBOutlet weak var windowDraggingViewLeadingConstraint: NSLayoutConstraint!

    private let tabCollectionViewModel: TabCollectionViewModel
    private let bookmarkManager: BookmarkManager = LocalBookmarkManager.shared
    lazy private var fireViewModel = FireViewModel()

    private var tabsCancellable: AnyCancellable?
    private var selectionIndexCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    required init?(coder: NSCoder) {
        fatalError("TabBarViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.updateScrollElasticity(with: tabMode)
        observeToScrollNotifications()
        subscribeToSelectionIndex()
        subscribeToIsBurning()

        warmupFireAnimation()
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        updateEmptyTabArea()
        tabCollectionViewModel.delegate = self
        reloadSelection()
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        frozenLayout = view.isMouseLocationInsideBounds()
        updateTabMode()
        updateEmptyTabArea()
        collectionView.invalidateLayout()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @IBAction func addButtonAction(_ sender: NSButton) {
        tabCollectionViewModel.appendNewTab(with: .homepage)
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

    private func subscribeToIsBurning() {
        fireViewModel.fire.$isBurning
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.isBurning, on: burnButton)
            .store(in: &cancellables)
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
            // when in fullscreen self.view.window will return NSToolbarFullScreenWindow instead of MainWindow
            guard let window = parent?.view.window else {
                os_log("AddressBarTextField: Window not available", type: .error)
                return
            }
            window.close()
        }
    }

    // MARK: - Window Dragging, Floating Add Button

    private var totalTabWidth: CGFloat {
        let selectedWidth = currentTabWidth(selected: true)
        let restOfTabsWidth = CGFloat(max(collectionView.numberOfItems(inSection: 0) - 1, 0)) * currentTabWidth()
        return selectedWidth + restOfTabsWidth
    }

    private func updateEmptyTabArea() {
        let totalTabWidth = self.totalTabWidth
        let emptySpace = scrollView.frame.size.width - totalTabWidth
        let plusButtonWidth = HorizontalSpace.buttonPadding.rawValue + HorizontalSpace.button.rawValue

        // Window dragging
        let leadingSpace = min(totalTabWidth + plusButtonWidth, scrollView.frame.size.width)
        windowDraggingViewLeadingConstraint.constant = leadingSpace

        // Add button
        if emptySpace > plusButton.frame.size.width {
            isAddButtonFloating = true
        } else {
            isAddButtonFloating = false
        }
        plusButton.alphaValue = isAddButtonFloating ? 0.0 : 1.0
        plusButton.isEnabled = !isAddButtonFloating
    }

    private var isAddButtonFloating = false

    // MARK: - Drag and Drop

    private var initialDraggingIndexPaths: Set<IndexPath>?
    private var currentDraggingIndexPath: IndexPath?

    private func moveItemIfNeeded(at indexPath: IndexPath, to newIndexPath: IndexPath) {
        guard newIndexPath != currentDraggingIndexPath else { return }

        let index = indexPath.item
        let newIndex = min(newIndexPath.item, max(tabCollectionViewModel.tabCollection.tabs.count - 1, 0))
        let newIndexPath = IndexPath(item: newIndex)

        guard index != newIndex else { return }
        currentDraggingIndexPath = newIndexPath

        tabCollectionViewModel.moveTab(at: index, to: newIndex)
        TabDragAndDropManager.shared.setSource(tabCollectionViewModel: tabCollectionViewModel, indexPath: newIndexPath)
    }

    private func moveToNewWindow(indexPath: IndexPath, droppingPoint: NSPoint? = nil) {
        guard tabCollectionViewModel.tabCollection.tabs.count > 1 else { return }
        guard let tabViewModel = tabCollectionViewModel.tabViewModel(at: indexPath.item) else {
            os_log("TabBarViewController: Failed to get tab view model", type: .error)
            return
        }

        let tab = tabViewModel.tab
        tabCollectionViewModel.remove(at: indexPath.item)
        WindowsManager.openNewWindow(with: tab, droppingPoint: droppingPoint)
    }

    // MARK: - Tab Width

    enum TabMode {
        case divided
        case overflow
    }

    private var frozenLayout = false
    private var tabMode = TabMode.divided

    private func updateTabMode(for numberOfItems: Int? = nil, updateLayout: Bool? = nil) {
        let items = CGFloat(numberOfItems ?? self.layoutNumberOfItems())
        let tabsWidth = scrollView.bounds.width

        let newMode: TabMode
        if max(0, (items - 1)) * TabBarViewItem.Width.minimum.rawValue + TabBarViewItem.Width.minimumSelected.rawValue < tabsWidth {
            newMode = .divided
        } else {
            newMode = .overflow
        }

        guard self.tabMode != newMode else { return }
        self.tabMode = newMode
        if updateLayout ?? !self.frozenLayout {
            self.updateLayout()
        }
    }

    private func updateLayout() {
        scrollView.updateScrollElasticity(with: tabMode)
        displayScrollButtons()
        updateEmptyTabArea()
        collectionView.invalidateLayout()
        frozenLayout = false
    }

    private var cachedLayoutNumberOfItems: Int?
    private func layoutNumberOfItems(removedIndex: Int? = nil) -> Int {
        let actualNumber = collectionView.numberOfItems(inSection: 0)
        // don't cache number of items before removal when closing the last Tab
        guard removedIndex ?? 0 < (actualNumber - 1) else {
            self.cachedLayoutNumberOfItems = nil
            return actualNumber
        }

        guard let numberOfItems = self.cachedLayoutNumberOfItems,
              // skip updating number of items when closing not last Tab
              numberOfItems > actualNumber,
              tabMode == .divided,
              self.view.isMouseLocationInsideBounds()
        else {
            self.cachedLayoutNumberOfItems = actualNumber
            return actualNumber
        }

        return numberOfItems
    }

    private func currentTabWidth(selected: Bool = false, removedIndex: Int? = nil) -> CGFloat {
        let numberOfItems = CGFloat(self.layoutNumberOfItems(removedIndex: removedIndex))
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

    override func mouseExited(with event: NSEvent) {
        guard !view.isMouseLocationInsideBounds(event.locationInWindow) else { return }

        if cachedLayoutNumberOfItems != collectionView.numberOfItems(inSection: 0) || frozenLayout {
            cachedLayoutNumberOfItems = nil
            let shouldScroll = collectionView.isAtEndScrollPosition
            collectionView.animator().performBatchUpdates({
                if shouldScroll {
                    collectionView.animator().scroll(CGPoint(x: scrollView.contentView.bounds.origin.x, y: 0))
                }
            }, completionHandler: { [weak self] _ in
                guard let self = self else { return }
                self.updateLayout()
                self.enableScrollButtons()
                self.hideTooltip()
            })
        }
    }

    // MARK: - Scroll Buttons

    private func observeToScrollNotifications() {
        scrollView.contentView.postsBoundsChangedNotifications = true

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(scrollViewBoundsDidChange(_:)),
                                               name: NSView.boundsDidChangeNotification,
                                               object: scrollView.contentView)
    }

    @objc private func scrollViewBoundsDidChange(_ sender: Any) {
        enableScrollButtons()
        hideTooltip()
    }

    private func enableScrollButtons() {
        rightScrollButton.isEnabled = !collectionView.isAtEndScrollPosition
        leftScrollButton.isEnabled = !collectionView.isAtStartScrollPosition
    }

    private func displayScrollButtons() {
        let scrollViewsAreHidden = tabMode == .divided
        rightScrollButton.isHidden = scrollViewsAreHidden
        leftScrollButton.isHidden = scrollViewsAreHidden
        rightShadowImageView.isHidden = scrollViewsAreHidden
        leftShadowImageView.isHidden = scrollViewsAreHidden
    }

    // MARK: - Tooltip

    // swiftlint:disable force_cast
    private var tooltipWindowController: TooltipWindowController = {
        let storyboard = NSStoryboard(name: "Tooltip", bundle: nil)
        return storyboard.instantiateController(withIdentifier: "TooltipWindowController") as! TooltipWindowController
    }()
    // swiftlint:enable force_cast

    func showTooltip(for tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem),
              let tabViewModel = tabCollectionViewModel.tabViewModel(at: indexPath.item) else {
            return
        }

        tooltipWindowController.tooltipViewController.display(tabViewModel: tabViewModel)

        guard let window = view.window, let clipView = collectionView.clipView else {
            os_log("TabBarViewController: Showing of tooltip window failed", type: .error)
            return
        }

        var point = view.bounds.origin
        point.y -= TooltipWindowController.VerticalSpace.tooltipPadding.rawValue
        point.x += scrollView.frame.origin.x + tabBarViewItem.view.frame.origin.x - clipView.bounds.origin.x
        let converted = window.convertPoint(toScreen: view.convert(point, to: nil))
        let timerInterval = TooltipWindowController.TimerInterval(from: tabBarViewItem.widthStage)
        tooltipWindowController.scheduleShowing(parentWindow: window, timerInterval: timerInterval, topLeftPoint: converted)
    }

    func hideTooltip() {
        tooltipWindowController.hide()
    }

}

extension TabBarViewController: TabCollectionViewModelDelegate {

    func tabCollectionViewModelDidAppend(_ tabCollectionViewModel: TabCollectionViewModel, selected: Bool) {
        appendToCollectionView(selected: selected)
    }

    func tabCollectionViewModelDidInsert(_ tabCollectionViewModel: TabCollectionViewModel,
                                         at index: Int,
                                         selected: Bool) {
        let indexPathSet = Set(arrayLiteral: IndexPath(item: index))
        if selected {
            collectionView.clearSelection(animated: true)
        }
        collectionView.animator().insertItems(at: indexPathSet)
        if selected {
            collectionView.selectItems(at: indexPathSet, scrollPosition: .centeredHorizontally)
        }

        updateTabMode()
        updateEmptyTabArea()
        hideTooltip()
    }

    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel,
                                didRemoveTabAt removedIndex: Int,
                                andSelectTabAt selectionIndex: Int?) {
        let removedIndexPathSet = Set(arrayLiteral: IndexPath(item: removedIndex))
        guard let selectionIndex = selectionIndex else {
            collectionView.animator().deleteItems(at: removedIndexPathSet)
            closeWindowIfNeeded()
            return
        }
        let selectionIndexPathSet = Set(arrayLiteral: IndexPath(item: selectionIndex))

        self.updateTabMode(for: collectionView.numberOfItems(inSection: 0) - 1, updateLayout: false)

        // don't scroll when mouse over and removing non-last Tab
        let shouldScroll = collectionView.isAtEndScrollPosition
            && (!self.view.isMouseLocationInsideBounds() || removedIndex == self.collectionView.numberOfItems(inSection: 0) - 1)
        let visiRect = collectionView.enclosingScrollView!.contentView.documentVisibleRect
        collectionView.animator().performBatchUpdates {
            let tabWidth = currentTabWidth(removedIndex: removedIndex)
            if shouldScroll {
                collectionView.animator().scroll(CGPoint(x: scrollView.contentView.bounds.origin.x - tabWidth, y: 0))
            }

            if collectionView.selectionIndexPaths != selectionIndexPathSet {
                collectionView.clearSelection()
                collectionView.animator().selectItems(at: selectionIndexPathSet, scrollPosition: .centeredHorizontally)
            }
            collectionView.animator().deleteItems(at: removedIndexPathSet)
        } completionHandler: { [weak self] _ in
            guard let self = self else { return }

            self.frozenLayout = self.view.isMouseLocationInsideBounds()
            if !self.frozenLayout {
                self.updateLayout()
            }
            self.updateEmptyTabArea()
            self.enableScrollButtons()
            self.hideTooltip()

            if !shouldScroll {
                self.collectionView.enclosingScrollView!.contentView.scroll(to: visiRect.origin)
            }
        }
    }

    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel, didMoveTabAt index: Int, to newIndex: Int) {
        let indexPath = IndexPath(item: index)
        let newIndexPath = IndexPath(item: newIndex)
        collectionView.animator().moveItem(at: indexPath, to: newIndexPath)

        updateTabMode()
        hideTooltip()
    }

    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel, didSelectAt selectionIndex: Int?) {
        if let selectionIndex = selectionIndex {
            let selectionIndexPathSet = Set(arrayLiteral: IndexPath(item: selectionIndex))
            collectionView.clearSelection(animated: true)
            collectionView.animator().selectItems(at: selectionIndexPathSet, scrollPosition: .centeredHorizontally)
            collectionView.scrollToSelected()
        } else {
            collectionView.clearSelection(animated: true)
        }
    }

    func tabCollectionViewModelDidMultipleChanges(_ tabCollectionViewModel: TabCollectionViewModel) {
        closeWindowIfNeeded()

        collectionView.reloadData()
        reloadSelection()

        updateTabMode()
        enableScrollButtons()
        hideTooltip()
        updateEmptyTabArea()

        if frozenLayout {
            updateLayout()
        }
    }

    private func appendToCollectionView(selected: Bool) {
        let lastIndex = max(0, tabCollectionViewModel.tabCollection.tabs.count - 1)
        let lastIndexPathSet = Set(arrayLiteral: IndexPath(item: lastIndex))

        if frozenLayout {
            updateLayout()
        }
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
        updateEmptyTabArea()
        hideTooltip()
    }

}

extension TabBarViewController: NSCollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: NSCollectionView,
                        layout collectionViewLayout: NSCollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> NSSize {
        var isItemSelected = tabCollectionViewModel.selectionIndex == indexPath.item

        if let draggingOverIndexPath = currentDraggingIndexPath {
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
            assertionFailure("TabBarViewController: Failed to get reusable TabBarViewItem instance")
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

    func collectionView(_ collectionView: NSCollectionView,
                        viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind,
                        at indexPath: IndexPath) -> NSView {

        let view = collectionView.makeSupplementaryView(ofKind: kind,
                                                        withIdentifier: TabBarFooter.identifier, for: indexPath)
        if let footer = view as? TabBarFooter {
            footer.addButton?.target = self
            footer.addButton?.action = #selector(addButtonAction(_:))
        }
        return view
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

        hideTooltip()
    }

    func collectionView(_ collectionView: NSCollectionView,
                        canDragItemsAt indexPaths: Set<IndexPath>,
                        with event: NSEvent) -> Bool {
        return true
    }

    func collectionView(_ collectionView: NSCollectionView,
                        pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        if let url = tabCollectionViewModel.tabCollection.tabs[indexPath.item].content.url {
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
        initialDraggingIndexPaths = indexPaths

        guard let indexPath = indexPaths.first, indexPaths.count == 1 else {
            os_log("TabBarViewController: More than 1 dragging index path", type: .error)
            return
        }
        currentDraggingIndexPath = indexPath
        TabDragAndDropManager.shared.setSource(tabCollectionViewModel: tabCollectionViewModel, indexPath: indexPath)
        hideTooltip()
    }

    static let dropToOpenDistance: CGFloat = 100

    func collectionView(_ collectionView: NSCollectionView,
                        draggingSession session: NSDraggingSession,
                        endedAt screenPoint: NSPoint,
                        dragOperation operation: NSDragOperation) {
        let draggingIndexPath = self.currentDraggingIndexPath
        self.initialDraggingIndexPaths = nil
        currentDraggingIndexPath = nil

        // Perform the drag and drop between multiple windows
        if TabDragAndDropManager.shared.performDragAndDropIfNeeded() { return }

        // Check whether the tab wasn't dropped to other app
        guard operation != .link && operation != .copy else { return }

        // Create a new window if the drop is too distant
        let frameRelativeToWindow = view.convert(view.bounds, to: nil)
        guard let frameRelativeToScreen = view.window?.convertToScreen(frameRelativeToWindow) else {
            os_log("TabBarViewController: Conversion to the screen coordinate system failed", type: .error)
            return
        }
        if !screenPoint.isNearRect(frameRelativeToScreen, allowedDistance: Self.dropToOpenDistance) {
            guard let draggingIndexPath = draggingIndexPath else {
                os_log("TabBarViewController: No current dragging index path", type: .error)
                return
            }
            moveToNewWindow(indexPath: draggingIndexPath, droppingPoint: screenPoint)
        }
    }

    func collectionView(_ collectionView: NSCollectionView,
                        validateDrop draggingInfo: NSDraggingInfo,
                        proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
                        dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        guard let currentDraggingIndexPath = currentDraggingIndexPath else {
            TabDragAndDropManager.shared.setDestination(tabCollectionViewModel: tabCollectionViewModel,
                                                        indexPath: proposedDropIndexPath.pointee as IndexPath)

            proposedDropOperation.pointee = .on
            return .private
        }

        let newIndexPath = proposedDropIndexPath.pointee as IndexPath
        moveItemIfNeeded(at: currentDraggingIndexPath, to: newIndexPath)

        proposedDropOperation.pointee = .before
        return .private
    }

    func collectionView(_ collectionView: NSCollectionView,
                        acceptDrop draggingInfo: NSDraggingInfo,
                        indexPath: IndexPath,
                        dropOperation: NSCollectionView.DropOperation) -> Bool {
        guard let draggingIndexPaths = initialDraggingIndexPaths else {
            // Droping from another TabBarViewController
            return true
        }

        guard draggingIndexPaths.count == 1 else {
            os_log("TabBarViewController: More than 1 item selected", type: .error)
            return false
        }

        return true
    }

    func collectionView(_ collectionView: NSCollectionView,
                        layout collectionViewLayout: NSCollectionViewLayout,
                        referenceSizeForFooterInSection section: Int) -> NSSize {
        let width = isAddButtonFloating ? HorizontalSpace.button.rawValue + HorizontalSpace.buttonPadding.rawValue : 0
        return NSSize(width: width, height: collectionView.frame.size.height)
    }

}

extension TabBarViewController: TabBarViewItemDelegate {

    func tabBarViewItem(_ tabBarViewItem: TabBarViewItem, isMouseOver: Bool) {
        if isMouseOver {
            // Show tooltip for visible tab bar items
            if collectionView.visibleRect.intersects(tabBarViewItem.view.frame) {
                showTooltip(for: tabBarViewItem)
            }
        } else {
            tooltipWindowController.scheduleHiding()
        }
    }

    func tabBarViewItemDuplicateAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            os_log("TabBarViewController: Failed to get index path of tab bar view item", type: .error)
            return
        }

        collectionView.clearSelection()
        tabCollectionViewModel.duplicateTab(at: indexPath.item)
    }

    func tabBarViewItemBookmarkThisPageAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem),
              let tabViewModel = tabCollectionViewModel.tabViewModel(at: indexPath.item),
              let url = tabViewModel.tab.content.url else {
            os_log("TabBarViewController: Failed to get index path of tab bar view item", type: .error)
            return
        }

        if !bookmarkManager.isUrlBookmarked(url: url) {
            bookmarkManager.makeBookmark(for: url, title: tabViewModel.title, isFavorite: false)
            Pixel.fire(.bookmark(fireproofed: .init(url: url), source: .tabMenu))
        }
    }

    func tabBarViewItemCloseAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            os_log("TabBarViewController: Failed to get index path of tab bar view item", type: .error)
            return
        }

        tabCollectionViewModel.remove(at: indexPath.item)
    }

    func tabBarViewItemTogglePermissionAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem),
              let permissions = tabCollectionViewModel.tabViewModel(at: indexPath.item)?.tab.permissions
        else {
            os_log("TabBarViewController: Failed to get index path of tab bar view item or its permissions", type: .error)
            return
        }

        if permissions.permissions.camera.isActive || permissions.permissions.microphone.isActive {
            permissions.set([.camera, .microphone], muted: true)
        } else if permissions.permissions.camera.isPaused || permissions.permissions.microphone.isPaused {
            permissions.set([.camera, .microphone], muted: false)
        } else {
            assertionFailure("Unexpected Tab Permissions state")
        }
    }

    func tabBarViewItemCloseOtherAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            os_log("TabBarViewController: Failed to get index path of tab bar view item", type: .error)
            return
        }

        tabCollectionViewModel.removeAllTabs(except: indexPath.item)
    }

    func tabBarViewItemCloseToTheRightAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            os_log("TabBarViewController: Failed to get index path of tab bar view item", type: .error)
            return
        }

        tabCollectionViewModel.removeTabs(after: indexPath.item)
    }

    func tabBarViewItemMoveToNewWindowAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            os_log("TabBarViewController: Failed to get index path of tab bar view item", type: .error)
            return
        }

        moveToNewWindow(indexPath: indexPath)
    }

    func tabBarViewItemFireproofSite(_ tabBarViewItem: TabBarViewItem) {
        if let url = tabCollectionViewModel.selectedTabViewModel?.tab.content.url,
           let host = url.host {
            Pixel.fire(.fireproof(kind: .init(url: url), suggested: .manual))
            FireproofDomains.shared.addToAllowed(domain: host)
        }
    }

    func tabBarViewItemRemoveFireproofing(_ tabBarViewItem: TabBarViewItem) {
        if let host = tabCollectionViewModel.selectedTabViewModel?.tab.content.url?.host {
            FireproofDomains.shared.remove(domain: host)
        }
    }

    func otherTabBarViewItemsState(for tabBarViewItem: TabBarViewItem) -> (hasItemsToTheLeft: Bool, hasItemsToTheRight: Bool) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            os_log("TabBarViewController: Failed to get index path of tab bar view item", type: .error)
            return (false, false)
        }
        return (hasItemsToTheLeft: indexPath.item > 0, hasItemsToTheRight: indexPath.item + 1 < tabCollectionViewModel.tabCollection.tabs.count)
    }

}

extension TabBarViewController {

    static let fireAnimation: AnimationView = {
        let view = AnimationView(name: "01_Fire_really_small")
        view.forceDisplayUpdate()
        return view
    }()

    func playFireAnimation() {

        Self.fireAnimation.contentMode = .scaleToFill
        Self.fireAnimation.frame = .init(x: 0,
                                y: 0,
                                width: view.window?.frame.width ?? 0,
                                height: view.window?.frame.height ?? 0)

        view.window?.contentView?.addSubview(Self.fireAnimation)
        Self.fireAnimation.play { _ in
            Self.fireAnimation.removeFromSuperview()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.fireViewModel.fire.burnAll(tabCollectionViewModel: self.tabCollectionViewModel)
        }

    }

    func warmupFireAnimation() {
        view.addSubview(Self.fireAnimation)
        DispatchQueue.main.async {
            Self.fireAnimation.removeFromSuperview()
        }
    }

}

// swiftlint:enable type_body_length
// swiftlint:enable file_length
