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
import SwiftUI

// swiftlint:disable file_length
// swiftlint:disable type_body_length

final class TabBarViewController: NSViewController {

    enum HorizontalSpace: CGFloat {
        case pinnedTabsScrollViewPadding = 76
        case button = 28
        case buttonPadding = 4
    }

    @IBOutlet weak var pinnedTabsContainerView: NSView!
    @IBOutlet weak var collectionView: TabBarCollectionView!
    @IBOutlet weak var scrollView: TabBarScrollView!
    @IBOutlet weak var pinnedTabsViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var rightScrollButton: MouseOverButton!
    @IBOutlet weak var leftScrollButton: MouseOverButton!
    @IBOutlet weak var rightShadowImageView: NSImageView!
    @IBOutlet weak var leftShadowImageView: NSImageView!
    @IBOutlet weak var plusButton: LongPressButton!
    @IBOutlet weak var fireButton: MouseOverAnimationButton!
    @IBOutlet weak var draggingSpace: NSView!
    @IBOutlet weak var windowDraggingViewLeadingConstraint: NSLayoutConstraint!

    let tabCollectionViewModel: TabCollectionViewModel

    private let bookmarkManager: BookmarkManager = LocalBookmarkManager.shared
    private lazy var pinnedTabsModel: PinnedTabsModel = .init(collection: WindowControllersManager.shared.pinnedTabsManager.tabCollection)
    private lazy var pinnedTabsView: PinnedTabsView = .init(model: pinnedTabsModel)
    private lazy var pinnedTabsHostingView = NSHostingView(rootView: pinnedTabsView)

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
        setupFireButton()
        setupPinnedTabsView()
    }

    private func setupPinnedTabsView() {
        pinnedTabsContainerView.addAndLayout(pinnedTabsHostingView)

        tabCollectionViewModel.$selectionIndex
            .map { selectedTabIndex -> Tab? in
                switch selectedTabIndex {
                case .pinned(let index):
                    return WindowControllersManager.shared.pinnedTabsManager.tabCollection.tabs[safe: index]
                default:
                    return nil
                }
            }
            .assign(to: \.selectedItem, onWeaklyHeld: pinnedTabsModel)
            .store(in: &cancellables)

        Publishers.CombineLatest(tabCollectionViewModel.$selectionIndex, $tabMode)
            .map { selectedTabIndex, tabMode -> Bool in
                if case .unpinned(0) = selectedTabIndex, tabMode == .divided {
                    return false
                }
                return true
            }
            .assign(to: \.shouldDrawLastItemSeparator, onWeaklyHeld: pinnedTabsModel)
            .store(in: &cancellables)

        pinnedTabsModel.tabsDidReorderPublisher
            .sink(receiveValue: WindowControllersManager.shared.pinnedTabsManager.tabCollection.reorderTabs)
            .store(in: &cancellables)

        pinnedTabsModel.$selectedItemIndex.dropFirst().removeDuplicates()
            .compactMap { $0 }
            .sink { [weak self] index in
                self?.deselectTabAndSelectPinnedTab(at: index)
            }
            .store(in: &cancellables)

        pinnedTabsModel.$hoveredItemIndex.dropFirst().removeDuplicates()
            .debounce(for: 0.05, scheduler: DispatchQueue.main)
            .sink { [weak self] index in
                self?.pinnedTabsViewDidUpdateHoveredItem(to: index)
            }
            .store(in: &cancellables)

        pinnedTabsModel.contextMenuActionPublisher
            .sink { [weak self] action in
                self?.handlePinnedTabContextMenuAction(action)
            }
            .store(in: &cancellables)
    }

    private func pinnedTabsViewDidUpdateHoveredItem(to index: Int?) {
        if let index = index {
            showPinnedTabPreview(at: index)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if self.view.isMouseLocationInsideBounds() == false {
                    self.hideTabPreview()
                }
            }
        }
    }

    private func deselectTabAndSelectPinnedTab(at index: Int) {
        hideTabPreview()
        if tabCollectionViewModel.selectionIndex != .pinned(index), tabCollectionViewModel.select(at: .pinned(index)) {
            let previousSelection = collectionView.selectionIndexPaths
            collectionView.clearSelection(animated: true)
            collectionView.reloadItems(at: previousSelection)
        }
    }

    private func handlePinnedTabContextMenuAction(_ action: PinnedTabsModel.ContextMenuAction) {
        switch action {
        case let .unpin(index):
            tabCollectionViewModel.unpinTab(at: index)
        case let .duplicate(index):
            duplicateTab(at: .pinned(index))
        case let .bookmark(tab):
            guard let url = tab.url, let tabViewModel = WindowControllersManager.shared.pinnedTabsManager.tabViewModels[tab] else {
                os_log("TabBarViewController: Failed to get url from tab")
                return
            }
            bookmarkTab(with: url, title: tabViewModel.title)
        case let .fireproof(tab):
            fireproof(tab)
        case let .removeFireproofing(tab):
            removeFireproofing(from: tab)
        case let .close(index):
            tabCollectionViewModel.remove(at: .pinned(index))
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        updateEmptyTabArea()
        tabCollectionViewModel.delegate = self
        reloadSelection()
        
        // Detect if tabs are clicked when the window is not in focus
        // https://app.asana.com/0/1177771139624306/1202033879471339
        addMouseMonitors()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        removeMouseMonitors()
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
        tabCollectionViewModel.appendNewTab(with: .homePage)
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

    private func setupFireButton() {
        fireButton.animationNames = MouseOverAnimationButton.AnimationNames(aqua: "flame-mouse-over", dark: "dark-flame-mouse-over")
    }

    private func reloadSelection() {
        guard tabCollectionViewModel.selectionIndex?.isUnpinnedTab == true,
              collectionView.selectionIndexPaths.first?.item != tabCollectionViewModel.selectionIndex?.index
        else {
            collectionView.updateItemsLeftToSelectedItems()
            return
        }

        guard let selectionIndex = tabCollectionViewModel.selectionIndex else {
            os_log("TabBarViewController: Selection index is nil", type: .error)
            return
        }

        if collectionView.selectionIndexPaths.count > 0 {
            collectionView.clearSelection()
        }

        let newSelectionIndexPath = IndexPath(item: selectionIndex.index)
        if tabMode == .divided {
            collectionView.animator().selectItems(at: [newSelectionIndexPath], scrollPosition: .centeredHorizontally)
        } else {
            collectionView.selectItems(at: [newSelectionIndexPath], scrollPosition: .centeredHorizontally)
        }
    }
    
    private func selectTabWithPoint(_ point: NSPoint) {
        let pointLocationOnPinnedTabsView = pinnedTabsHostingView.convert(point, from: view)
        if let index = pinnedTabsView.itemIndex(for: pointLocationOnPinnedTabsView) {
            tabCollectionViewModel.select(at: .pinned(index))
        } else {
            let pointLocationOnCollectionView = collectionView.convert(point, from: view)
            if let indexPath = collectionView.indexPathForItem(at: pointLocationOnCollectionView) {
                tabCollectionViewModel.select(at: .unpinned(indexPath.item))
            }
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
        tabCollectionViewModel.remove(at: .unpinned(indexPath.item), published: false)
        WindowsManager.openNewWindow(with: tab, droppingPoint: droppingPoint)
    }
    
    // MARK: - Mouse Monitor
    
    private var mouseDownMonitor: Any?

    private func addMouseMonitors() {
        guard mouseDownMonitor == nil else { return }
        
        mouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.mouseDown(with: event)
        }
    }

    private func removeMouseMonitors() {
        if let monitor = mouseDownMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        mouseDownMonitor = nil
    }
    
    func mouseDown(with event: NSEvent) -> NSEvent? {
        if event.window === view.window,
           view.window?.isMainWindow == false,
           let point = view.mouseLocationInsideBounds(event.locationInWindow) {
            selectTabWithPoint(point)
        }
        
        return event
    }

    // MARK: - Tab Width

    enum TabMode: Equatable {
        case divided
        case overflow
    }

    private var frozenLayout = false
    @Published private var tabMode = TabMode.divided

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
                self.hideTabPreview()
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
        hideTabPreview()
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

    // MARK: - Tab Preview

    private var tabPreviewWindowController: TabPreviewWindowController = {
        let storyboard = NSStoryboard(name: "TabPreview", bundle: nil)
        // swiftlint:disable:next force_cast
        return storyboard.instantiateController(withIdentifier: "TabPreviewWindowController") as! TabPreviewWindowController
    }()

    private func showTabPreview(for tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem),
              let tabViewModel = tabCollectionViewModel.tabViewModel(at: indexPath.item),
              let clipView = collectionView.clipView
        else {
            os_log("TabBarViewController: Showing tab preview window failed", type: .error)
            return
        }

        let position = scrollView.frame.minX + tabBarViewItem.view.frame.minX - clipView.bounds.origin.x
        showTabPreview(for: tabViewModel, from: position, after: .init(from: tabBarViewItem.widthStage))
    }

    private func showPinnedTabPreview(at index: Int) {
        guard let tabViewModel = tabCollectionViewModel.pinnedTabsManager.tabViewModel(at: index) else {
            os_log("TabBarViewController: Showing pinned tab preview window failed", type: .error)
            return
        }

        let position = pinnedTabsContainerView.frame.minX + PinnedTabView.Const.dimension * CGFloat(index)
        showTabPreview(for: tabViewModel, from: position, after: .init(from: .withoutTitle))
    }

    private func showTabPreview(
        for tabViewModel: TabViewModel,
        from xPosition: CGFloat,
        after interval: TabPreviewWindowController.TimerInterval
    ) {
        tabPreviewWindowController.tabPreviewViewController.display(tabViewModel: tabViewModel)

        guard let window = view.window else {
            os_log("TabBarViewController: Showing tab preview window failed", type: .error)
            return
        }

        var point = view.bounds.origin
        point.y -= TabPreviewWindowController.VerticalSpace.padding.rawValue
        point.x += xPosition
        let converted = window.convertPoint(toScreen: view.convert(point, to: nil))
        tabPreviewWindowController.scheduleShowing(parentWindow: window, timerInterval: interval, topLeftPoint: converted)
    }

    func hideTabPreview() {
        tabPreviewWindowController.hide()
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
        hideTabPreview()
    }

    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel,
                                didRemoveTabAt removedIndex: Int,
                                andSelectTabAt selectionIndex: Int?) {
        let removedIndexPathSet = Set(arrayLiteral: IndexPath(item: removedIndex))
        guard let selectionIndex = selectionIndex else {
            collectionView.animator().deleteItems(at: removedIndexPathSet)
            return
        }
        let selectionIndexPathSet = Set(arrayLiteral: IndexPath(item: selectionIndex))

        self.updateTabMode(for: collectionView.numberOfItems(inSection: 0) - 1, updateLayout: false)

        // don't scroll when mouse over and removing non-last Tab
        let shouldScroll = collectionView.isAtEndScrollPosition
            && (!self.view.isMouseLocationInsideBounds() || removedIndex == self.collectionView.numberOfItems(inSection: 0) - 1)
        let visiRect = collectionView.enclosingScrollView!.contentView.documentVisibleRect
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15

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
                self.hideTabPreview()

                if !shouldScroll {
                    self.collectionView.enclosingScrollView!.contentView.scroll(to: visiRect.origin)
                }
            }
        }
    }

    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel, didMoveTabAt index: Int, to newIndex: Int) {
        let indexPath = IndexPath(item: index)
        let newIndexPath = IndexPath(item: newIndex)
        collectionView.animator().moveItem(at: indexPath, to: newIndexPath)

        updateTabMode()
        hideTabPreview()
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
        collectionView.reloadData()
        reloadSelection()

        updateTabMode()
        enableScrollButtons()
        hideTabPreview()
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
        hideTabPreview()
    }

    // MARK: - Tab Actions

    private func duplicateTab(at tabIndex: TabIndex) {
        if tabIndex.isUnpinnedTab {
            collectionView.clearSelection()
        }
        tabCollectionViewModel.duplicateTab(at: tabIndex)
    }

    private func bookmarkTab(with url: URL, title: String) {
        if !bookmarkManager.isUrlBookmarked(url: url) {
            bookmarkManager.makeBookmark(for: url, title: title, isFavorite: false)
            Pixel.fire(.bookmark(fireproofed: .init(url: url), source: .tabMenu))
        }
    }

    private func fireproof(_ tab: Tab) {
        guard let url = tab.url, let host = url.host else {
            os_log("TabBarViewController: Failed to get url of tab bar view item", type: .error)
            return
        }

        Pixel.fire(.fireproof(kind: .init(url: url), suggested: .manual))
        FireproofDomains.shared.add(domain: host)
    }

    private func removeFireproofing(from tab: Tab) {
        guard let host = tab.url?.host else {
            os_log("TabBarViewController: Failed to get url of tab bar view item", type: .error)
            return
        }

        FireproofDomains.shared.remove(domain: host)
    }
}

extension TabBarViewController: NSCollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: NSCollectionView,
                        layout collectionViewLayout: NSCollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> NSSize {
        var isItemSelected = tabCollectionViewModel.selectionIndex == .unpinned(indexPath.item)

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

    func collectionView(
        _ collectionView: NSCollectionView,
        didEndDisplaying item: NSCollectionViewItem,
        forRepresentedObjectAt indexPath: IndexPath) {

        (item as? TabBarViewItem)?.clear()
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
            tabCollectionViewModel.select(at: .unpinned(indexPath.item))

            // Poor old NSCollectionView
            DispatchQueue.main.async {
                self.collectionView.scrollToSelected()
            }
        }

        hideTabPreview()
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
            return URL.blankPage as NSURL
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
        hideTabPreview()
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
            // Show tab preview for visible tab bar items
            if collectionView.visibleRect.intersects(tabBarViewItem.view.frame) {
                showTabPreview(for: tabBarViewItem)
            }
        } else {
            tabPreviewWindowController.scheduleHiding()
        }
    }

    func tabBarViewItemDuplicateAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            os_log("TabBarViewController: Failed to get index path of tab bar view item", type: .error)
            return
        }

        duplicateTab(at: .unpinned(indexPath.item))
    }

    func tabBarViewItemCanBePinned(_ tabBarViewItem: TabBarViewItem) -> Bool {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            os_log("TabBarViewController: Failed to get index path of tab bar view item", type: .error)
            return false
        }

        return tabCollectionViewModel.tabViewModel(at: indexPath.item)?.tab.isUrl ?? false
    }

    func tabBarViewItemPinAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            os_log("TabBarViewController: Failed to get index path of tab bar view item", type: .error)
            return
        }

        collectionView.clearSelection()
        tabCollectionViewModel.pinTab(at: indexPath.item)
    }

    func tabBarViewItemBookmarkThisPageAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem),
              let tabViewModel = tabCollectionViewModel.tabViewModel(at: indexPath.item),
              let url = tabViewModel.tab.content.url else {
            os_log("TabBarViewController: Failed to get index path of tab bar view item", type: .error)
            return
        }

        bookmarkTab(with: url, title: tabViewModel.title)
    }

    func tabBarViewItemCloseAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            os_log("TabBarViewController: Failed to get index path of tab bar view item", type: .error)
            return
        }

        tabCollectionViewModel.remove(at: .unpinned(indexPath.item))
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
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem),
              let tab = tabCollectionViewModel.tabCollection.tabs[safe: indexPath.item]
        else {
            os_log("TabBarViewController: Failed to get tab from tab bar view item", type: .error)
            return
        }

        fireproof(tab)
    }

    func tabBarViewItemRemoveFireproofing(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem),
              let tab = tabCollectionViewModel.tabCollection.tabs[safe: indexPath.item]
        else {
            os_log("TabBarViewController: Failed to get tab from tab bar view item", type: .error)
            return
        }

        removeFireproofing(from: tab)
    }

    func otherTabBarViewItemsState(for tabBarViewItem: TabBarViewItem) -> OtherTabBarViewItemsState {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            os_log("TabBarViewController: Failed to get index path of tab bar view item", type: .error)
            return .init(hasItemsToTheLeft: false, hasItemsToTheRight: false)
        }
        return .init(hasItemsToTheLeft: indexPath.item > 0,
                     hasItemsToTheRight: indexPath.item + 1 < tabCollectionViewModel.tabCollection.tabs.count)
    }

}
