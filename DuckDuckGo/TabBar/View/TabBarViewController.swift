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
import Combine
import Common
import Lottie
import SwiftUI
import WebKit
import os.log
import RemoteMessaging

final class TabBarViewController: NSViewController, TabBarRemoteMessagePresenting {

    enum HorizontalSpace: CGFloat {
        case pinnedTabsScrollViewPadding = 76
        case button = 28
        case buttonPadding = 4
    }

    @IBOutlet weak var visualEffectBackgroundView: NSVisualEffectView!
    @IBOutlet weak var pinnedTabsContainerView: NSView!
    @IBOutlet private weak var collectionView: TabBarCollectionView!
    @IBOutlet private weak var scrollView: TabBarScrollView!
    @IBOutlet weak var pinnedTabsViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var pinnedTabsWindowDraggingView: WindowDraggingView!
    @IBOutlet weak var rightScrollButton: MouseOverButton!
    @IBOutlet weak var leftScrollButton: MouseOverButton!
    @IBOutlet weak var rightShadowImageView: NSImageView!
    @IBOutlet weak var leftShadowImageView: NSImageView!
    @IBOutlet weak var fireButton: MouseOverAnimationButton!
    @IBOutlet weak var draggingSpace: NSView!
    @IBOutlet weak var windowDraggingViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var burnerWindowBackgroundView: NSImageView!

    @IBOutlet weak var addTabButton: MouseOverButton!

    private var fireButtonMouseOverCancellable: AnyCancellable?

    private var addNewTabButtonFooter: TabBarFooter? {
        guard let indexPath = collectionView.indexPathsForVisibleSupplementaryElements(ofKind: NSCollectionView.elementKindSectionFooter).first,
              let footerView = collectionView.supplementaryView(forElementKind: NSCollectionView.elementKindSectionFooter, at: indexPath) else { return nil }
        return footerView as? TabBarFooter ?? {
            assertionFailure("Unexpected \(footerView), expected TabBarFooter")
            return nil
        }()
    }
    let tabCollectionViewModel: TabCollectionViewModel
    var isInteractionPrevented: Bool = false {
        didSet {
            addNewTabButtonFooter?.isEnabled = !isInteractionPrevented
        }
    }

    private let bookmarkManager: BookmarkManager = LocalBookmarkManager.shared
    private let pinnedTabsViewModel: PinnedTabsViewModel?
    private let pinnedTabsView: PinnedTabsView?
    private let pinnedTabsHostingView: PinnedTabsHostingView?

    var shouldDisplayTabPreviews: Bool = true
    private var selectionIndexCancellable: AnyCancellable?
    private var mouseDownCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    // TabBarRemoteMessagePresentable
    var tabBarRemoteMessageViewModel: TabBarRemoteMessageViewModel
    var tabBarRemoteMessagePopover: NSPopover?
    var tabBarRemoteMessagePopoverHoverTimer: Timer?
    var feedbackBarButtonHostingController: NSHostingController<TabBarRemoteMessageView>?
    var tabBarRemoteMessageCancellable: AnyCancellable?

    @IBOutlet weak var shadowView: TabShadowView!

    @IBOutlet weak var rightSideStackView: NSStackView!
    var footerCurrentWidthDimension: CGFloat {
        if tabMode == .overflow {
            return 0.0
        } else {
            return HorizontalSpace.button.rawValue + HorizontalSpace.buttonPadding.rawValue
        }
    }

    static func create(tabCollectionViewModel: TabCollectionViewModel, activeRemoteMessageModel: ActiveRemoteMessageModel) -> TabBarViewController {
        NSStoryboard(name: "TabBar", bundle: nil).instantiateInitialController { coder in
            self.init(coder: coder, tabCollectionViewModel: tabCollectionViewModel, activeRemoteMessageModel: activeRemoteMessageModel)
        }!
    }

    required init?(coder: NSCoder) {
        fatalError("TabBarViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel, activeRemoteMessageModel: ActiveRemoteMessageModel) {
        self.tabCollectionViewModel = tabCollectionViewModel
        let tabBarActiveRemoteMessageModel = TabBarActiveRemoteMessage(activeRemoteMessageModel: activeRemoteMessageModel)
        self.tabBarRemoteMessageViewModel = TabBarRemoteMessageViewModel(activeRemoteMessageModel: tabBarActiveRemoteMessageModel,
                                                                         isFireWindow: tabCollectionViewModel.isBurner)
        if !tabCollectionViewModel.isBurner, let pinnedTabCollection = tabCollectionViewModel.pinnedTabsManager?.tabCollection {
            let pinnedTabsViewModel = PinnedTabsViewModel(collection: pinnedTabCollection)
            let pinnedTabsView = PinnedTabsView(model: pinnedTabsViewModel)
            self.pinnedTabsViewModel = pinnedTabsViewModel
            self.pinnedTabsView = pinnedTabsView
            self.pinnedTabsHostingView = PinnedTabsHostingView(rootView: pinnedTabsView)
        } else {
            self.pinnedTabsViewModel = nil
            self.pinnedTabsView = nil
            self.pinnedTabsHostingView = nil
        }

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.updateScrollElasticity(with: tabMode)
        observeToScrollNotifications()
        subscribeToSelectionIndex()
        setupFireButton()
        setupPinnedTabsView()
        subscribeToTabModeChanges()
        setupAddTabButton()
        setupAsBurnerWindowIfNeeded()
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        updateEmptyTabArea()
        tabCollectionViewModel.delegate = self
        reloadSelection()

        // Detect if tabs are clicked when the window is not in focus
        // https://app.asana.com/0/1177771139624306/1202033879471339
        addMouseMonitors()
        addTabBarRemoteMessageListener()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        mouseDownCancellable = nil
        tabBarRemoteMessageCancellable = nil
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

    @objc func addButtonAction(_ sender: NSButton) {
        tabCollectionViewModel.insertOrAppendNewTab()
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
        fireButton.image = .burn
        fireButton.toolTip = UserText.clearBrowsingHistoryTooltip
        fireButton.animationNames = MouseOverAnimationButton.AnimationNames(aqua: "flame-mouse-over", dark: "dark-flame-mouse-over")
        fireButton.sendAction(on: .leftMouseDown)
        fireButtonMouseOverCancellable = fireButton.publisher(for: \.isMouseOver)
            .first(where: { $0 }) // only interested when mouse is over
            .sink(receiveValue: { [weak self] _ in
                self?.stopFireButtonPulseAnimation()
            })
    }

    private func setupAsBurnerWindowIfNeeded() {
        if tabCollectionViewModel.isBurner {
            burnerWindowBackgroundView.isHidden = false
            fireButton.isAnimationEnabled = false
            fireButton.backgroundColor = NSColor.fireButtonRedBackground
            fireButton.mouseOverColor = NSColor.fireButtonRedHover
            fireButton.mouseDownColor = NSColor.fireButtonRedPressed
            fireButton.normalTintColor = NSColor.white
            fireButton.mouseDownTintColor = NSColor.white
            fireButton.mouseOverTintColor = NSColor.white
        }
    }

    private func setupPinnedTabsView() {
        layoutPinnedTabsView()
        subscribeToPinnedTabsViewModelOutputs()
        subscribeToPinnedTabsViewModelInputs()
        subscribeToPinnedTabsHostingView()
    }

    private func layoutPinnedTabsView() {
        guard let pinnedTabsHostingView = pinnedTabsHostingView else {
            return
        }

        pinnedTabsHostingView.translatesAutoresizingMaskIntoConstraints = false
        pinnedTabsContainerView.addSubview(pinnedTabsHostingView)

        NSLayoutConstraint.activate([
            pinnedTabsHostingView.leadingAnchor.constraint(equalTo: pinnedTabsContainerView.leadingAnchor),
            pinnedTabsHostingView.topAnchor.constraint(lessThanOrEqualTo: pinnedTabsContainerView.topAnchor),
            pinnedTabsHostingView.bottomAnchor.constraint(equalTo: pinnedTabsContainerView.bottomAnchor),
            pinnedTabsHostingView.trailingAnchor.constraint(equalTo: pinnedTabsContainerView.trailingAnchor)
        ])
    }

    private func subscribeToPinnedTabsViewModelInputs() {
        guard let pinnedTabsViewModel = pinnedTabsViewModel else { return }

        tabCollectionViewModel.$selectionIndex
            .map { [weak self] selectedTabIndex -> Tab? in
                switch selectedTabIndex {
                case .pinned(let index):
                    return self?.pinnedTabsViewModel?.items[safe: index]
                default:
                    return nil
                }
            }
            .assign(to: \.selectedItem, onWeaklyHeld: pinnedTabsViewModel)
            .store(in: &cancellables)

        Publishers.CombineLatest(tabCollectionViewModel.$selectionIndex, $tabMode)
            .map { selectedTabIndex, tabMode -> Bool in
                if case .unpinned(0) = selectedTabIndex, tabMode == .divided {
                    return false
                }
                return true
            }
            .assign(to: \.shouldDrawLastItemSeparator, onWeaklyHeld: pinnedTabsViewModel)
            .store(in: &cancellables)
    }

    private func subscribeToPinnedTabsViewModelOutputs() {
        guard let pinnedTabsViewModel = pinnedTabsViewModel else { return }

        pinnedTabsViewModel.tabsDidReorderPublisher
            .sink { [weak self] tabs in
                self?.tabCollectionViewModel.pinnedTabsManager?.tabCollection.reorderTabs(tabs)
            }
            .store(in: &cancellables)

        pinnedTabsViewModel.$selectedItemIndex.dropFirst().removeDuplicates()
            .compactMap { $0 }
            .sink { [weak self] index in
                self?.deselectTabAndSelectPinnedTab(at: index)
            }
            .store(in: &cancellables)

        pinnedTabsViewModel.$hoveredItemIndex.dropFirst().removeDuplicates()
            .debounce(for: 0.05, scheduler: DispatchQueue.main)
            .sink { [weak self] index in
                self?.pinnedTabsViewDidUpdateHoveredItem(to: index)
            }
            .store(in: &cancellables)

        pinnedTabsViewModel.contextMenuActionPublisher
            .sink { [weak self] action in
                self?.handlePinnedTabContextMenuAction(action)
            }
            .store(in: &cancellables)

        pinnedTabsViewModel.$dragMovesWindow.map(!)
            .assign(to: \.pinnedTabsWindowDraggingView.isHidden, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    private func subscribeToPinnedTabsHostingView() {
        pinnedTabsHostingView?.middleClickPublisher
            .compactMap { [weak self] in self?.pinnedTabsView?.index(forItemAt: $0) }
            .sink { [weak self] index in
                self?.tabCollectionViewModel.remove(at: .pinned(index))
            }
            .store(in: &cancellables)

        pinnedTabsWindowDraggingView.mouseDownPublisher
            .sink { [weak self] _ in
                self?.pinnedTabsViewModel?.selectedItem = self?.pinnedTabsViewModel?.items.first
            }
            .store(in: &cancellables)
    }

    private func pinnedTabsViewDidUpdateHoveredItem(to index: Int?) {
        if let index = index {
            showPinnedTabPreview(at: index)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if self.view.isMouseLocationInsideBounds() == false {
                    self.hideTabPreview(allowQuickRedisplay: true)
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

    private func handlePinnedTabContextMenuAction(_ action: PinnedTabsViewModel.ContextMenuAction) {
        switch action {
        case let .unpin(index):
            tabCollectionViewModel.unpinTab(at: index)
        case let .duplicate(index):
            duplicateTab(at: .pinned(index))
        case let .bookmark(tab):
            guard let url = tab.url, let tabViewModel = tabCollectionViewModel.pinnedTabsManager?.tabViewModels[tab] else {
                Logger.general.debug("TabBarViewController: Failed to get url from tab")
                return
            }
            bookmarkTab(with: url, title: tabViewModel.title)
        case let .removeBookmark(tab):
            guard let url = tab.url else {
                Logger.general.debug("TabBarViewController: Failed to get url from tab")
                return
            }
            deleteBookmark(with: url)
        case let .fireproof(tab):
            fireproof(tab)
        case let .removeFireproofing(tab):
            removeFireproofing(from: tab)
        case let .close(index):
            tabCollectionViewModel.remove(at: .pinned(index))
        case let .muteOrUnmute(tab):
            tab.muteUnmuteTab()
        }
    }

    private func reloadSelection() {
        guard tabCollectionViewModel.selectionIndex?.isUnpinnedTab == true,
              collectionView.selectionIndexPaths.first?.item != tabCollectionViewModel.selectionIndex?.item
        else {
            collectionView.updateItemsLeftToSelectedItems()
            return
        }

        guard let selectionIndex = tabCollectionViewModel.selectionIndex else {
            Logger.general.error("TabBarViewController: Selection index is nil")
            return
        }

        if collectionView.selectionIndexPaths.count > 0 {
            collectionView.clearSelection()
        }

        let newSelectionIndexPath = IndexPath(item: selectionIndex.item)
        if tabMode == .divided {
            collectionView.animator().selectItems(at: [newSelectionIndexPath], scrollPosition: .centeredHorizontally)
        } else {
            collectionView.selectItems(at: [newSelectionIndexPath], scrollPosition: .centeredHorizontally)
            collectionView.scrollToSelected()
        }
    }

    private func selectTab(with event: NSEvent) {
        let locationInWindow = event.locationInWindow

        if let point = pinnedTabsHostingView?.mouseLocationInsideBounds(locationInWindow),
           let index = pinnedTabsView?.index(forItemAt: point) {

            tabCollectionViewModel.select(at: .pinned(index))

        } else if let point = collectionView.mouseLocationInsideBounds(locationInWindow),
                  let indexPath = collectionView.indexPathForItem(at: point) {
            tabCollectionViewModel.select(at: .unpinned(indexPath.item))
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
        let plusButtonWidth = footerCurrentWidthDimension

        // Window dragging
        let leadingSpace = min(totalTabWidth + plusButtonWidth, scrollView.frame.size.width)
        windowDraggingViewLeadingConstraint.constant = leadingSpace
    }

    // MARK: - Drag and Drop

    private func moveItemIfNeeded(to newIndex: Int) {
        guard TabDragAndDropManager.shared.sourceUnit?.tabCollectionViewModel === tabCollectionViewModel,
              tabCollectionViewModel.tabCollection.tabs.indices.contains(newIndex),
              let oldIndex = TabDragAndDropManager.shared.sourceUnit?.index,
              oldIndex != newIndex else { return }

        tabCollectionViewModel.moveTab(at: oldIndex, to: newIndex)
        TabDragAndDropManager.shared.setSource(tabCollectionViewModel: tabCollectionViewModel, index: newIndex)
    }

    private func moveToNewWindow(from index: Int, droppingPoint: NSPoint? = nil, burner: Bool) {
        // only allow dragging Tab out when there‘s tabs (or pinned tabs) left
        guard tabCollectionViewModel.tabCollection.tabs.count > 1 || pinnedTabsViewModel?.items.isEmpty == false else { return }
        guard let tabViewModel = tabCollectionViewModel.tabViewModel(at: index) else {
            assertionFailure("TabBarViewController: Failed to get tab view model")
            return
        }

        let tab = tabViewModel.tab
        tabCollectionViewModel.remove(at: .unpinned(index), published: false)
        WindowsManager.openNewWindow(with: tab, droppingPoint: droppingPoint)
    }

    // MARK: - Mouse Monitor

    private func addMouseMonitors() {
        mouseDownCancellable = NSEvent.addLocalCancellableMonitor(forEventsMatching: .leftMouseDown) { [weak self] event in
            guard let self else { return event }
            return self.mouseDown(with: event)
        }
    }

    func mouseDown(with event: NSEvent) -> NSEvent? {
        if event.window === view.window,
           view.window?.isMainWindow == false {

            selectTab(with: event)
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
        if max(0, (items - 1)) * TabBarViewItem.Width.minimum + TabBarViewItem.Width.minimumSelected < tabsWidth {
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

        guard let numberOfItems = self.cachedLayoutNumberOfItems,
              // skip updating number of items when closing not last Tab
              actualNumber > 0 && numberOfItems > actualNumber,
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
        guard numberOfItems > 0 else {
            return 0
        }

        let tabsWidth = scrollView.bounds.width - footerCurrentWidthDimension
        let minimumWidth = selected ? TabBarViewItem.Width.minimumSelected : TabBarViewItem.Width.minimum

        if tabMode == .divided {
            var dividedWidth = tabsWidth / numberOfItems
            // If tabs are shorter than minimumSelected, then the selected tab takes more space
            if dividedWidth < TabBarViewItem.Width.minimumSelected {
                dividedWidth = (tabsWidth - TabBarViewItem.Width.minimumSelected) / (numberOfItems - 1)
            }
            return min(TabBarViewItem.Width.maximum, max(minimumWidth, dividedWidth)).rounded()
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
                self.hideTabPreview(allowQuickRedisplay: true)
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
        hideTabPreview(allowQuickRedisplay: true)
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
        addTabButton.isHidden = scrollViewsAreHidden
    }

    private func setupAddTabButton() {
        addTabButton.delegate = self
        addTabButton.registerForDraggedTypes([.string])
        addTabButton.target = self
        addTabButton.action = #selector(addButtonAction(_:))
        addTabButton.toolTip = UserText.newTabTooltip
    }

    private func subscribeToTabModeChanges() {
        $tabMode
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] _ in
            self?.displayScrollButtons()
        })
        .store(in: &cancellables)
    }

    // MARK: - Tab Preview

    private lazy var tabPreviewWindowController = TabPreviewWindowController()

    private func showTabPreview(for tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem),
              let tabViewModel = tabCollectionViewModel.tabViewModel(at: indexPath.item),
              let clipView = collectionView.clipView
        else {
            Logger.general.error("TabBarViewController: Showing tab preview window failed")
            return
        }

        let position = scrollView.frame.minX + tabBarViewItem.view.frame.minX - clipView.bounds.origin.x
        showTabPreview(for: tabViewModel, from: position)
    }

    private func showPinnedTabPreview(at index: Int) {
        guard let tabViewModel = tabCollectionViewModel.pinnedTabsManager?.tabViewModel(at: index) else {
            Logger.general.error("TabBarViewController: Showing pinned tab preview window failed")
            return
        }

        let position = pinnedTabsContainerView.frame.minX + PinnedTabView.Const.dimension * CGFloat(index)
        showTabPreview(for: tabViewModel, from: position)
    }

    private func showTabPreview(
        for tabViewModel: TabViewModel,
        from xPosition: CGFloat) {
            if !shouldDisplayTabPreviews { return }

            let isSelected = tabCollectionViewModel.selectedTabViewModel === tabViewModel
            tabPreviewWindowController.tabPreviewViewController.display(tabViewModel: tabViewModel,
                                                                        isSelected: isSelected)

            guard let window = view.window else {
                Logger.general.error("TabBarViewController: Showing tab preview window failed")
                return
            }

            var point = view.bounds.origin
            point.y -= TabPreviewWindowController.padding
            point.x += xPosition
            let pointInWindow = view.convert(point, to: nil)
            tabPreviewWindowController.show(parentWindow: window, topLeftPointInWindow: pointInWindow)
        }

    func hideTabPreview(allowQuickRedisplay: Bool = false) {
        tabPreviewWindowController.hide(allowQuickRedisplay: allowQuickRedisplay)
    }

}

extension TabBarViewController: MouseOverButtonDelegate {

    func mouseOverButton(_ sender: MouseOverButton, draggingEntered info: any NSDraggingInfo, isMouseOver: UnsafeMutablePointer<Bool>) -> NSDragOperation {
        assert(sender === addTabButton || sender === addNewTabButtonFooter?.addButton)
        let pasteboard = info.draggingPasteboard

        if let types = pasteboard.types, types.contains(.string) {
            return .copy
        }
        return .none
    }

    func mouseOverButton(_ sender: MouseOverButton, performDragOperation info: any NSDraggingInfo) -> Bool {
        assert(sender === addTabButton || sender === addNewTabButtonFooter?.addButton)
        if let string = info.draggingPasteboard.string(forType: .string), let url = URL.makeURL(from: string) {
            tabCollectionViewModel.insertOrAppendNewTab(.url(url, credential: nil, source: .appOpenUrl))
            return true
        }

        return true
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
            collectionView.scrollToSelected()
        }

        updateTabMode()
        updateEmptyTabArea()
        hideTabPreview()
        if tabMode == .overflow {
            let isLastItem = collectionView.numberOfItems(inSection: 0) == index + 1
            if isLastItem {
                scrollCollectionViewToEnd()
            } else {
                collectionView.scroll(to: IndexPath(item: index))
            }
        }
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

        if selected {
            collectionView.clearSelection()
        }

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
            scrollCollectionViewToEnd()
        }
        updateEmptyTabArea()
        hideTabPreview()
    }

    private func scrollCollectionViewToEnd() {
        // Old frameworks... need a special treatment
        collectionView.scrollToEnd { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.collectionView.scrollToEnd()
            }
        }
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
        }
    }

    private func deleteBookmark(with url: URL) {
        guard let bookmark = bookmarkManager.getBookmark(for: url) else {
            Logger.general.error("TabBarViewController: Failed to fetch bookmark for url \(url)")
            return
        }
        bookmarkManager.remove(bookmark: bookmark, undoManager: nil)
    }

    private func fireproof(_ tab: Tab) {
        guard let url = tab.url, let host = url.host else {
            Logger.general.error("TabBarViewController: Failed to get url of tab bar view item")
            return
        }

        FireproofDomains.shared.add(domain: host)
    }

    private func removeFireproofing(from tab: Tab) {
        guard let host = tab.url?.host else {
            Logger.general.error("TabBarViewController: Failed to get url of tab bar view item")
            return
        }

        FireproofDomains.shared.remove(domain: host)
    }

    // MARK: - TabViewItem

    func urlAndTitle(for tabBarViewItem: TabBarViewItem) -> (url: URL, title: String)? {
        guard
            let indexPath = collectionView.indexPath(for: tabBarViewItem),
            let tabViewModel = tabCollectionViewModel.tabViewModel(at: indexPath.item),
            let url = tabViewModel.tab.content.userEditableUrl
        else {
            Logger.general.error("TabBarViewController: Failed to get index path of tab bar view item")
            return nil
        }

        return (url, tabViewModel.title)
    }
}

// MARK: - NSCollectionViewDelegateFlowLayout

extension TabBarViewController: NSCollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        let isItemSelected = tabCollectionViewModel.selectionIndex == .unpinned(indexPath.item)
        return NSSize(width: self.currentTabWidth(selected: isItemSelected), height: TabBarViewItem.Height.standard)
    }

}

// MARK: - NSCollectionViewDataSource

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
        tabBarViewItem.isBurner = tabCollectionViewModel.isBurner
        tabBarViewItem.subscribe(to: tabViewModel)

        return tabBarViewItem
    }

    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind, at indexPath: IndexPath) -> NSView {
        // swiftlint:disable:next force_cast
        let view = collectionView.makeSupplementaryView(ofKind: kind, withIdentifier: TabBarFooter.identifier, for: indexPath) as! TabBarFooter
        view.target = self
        return view
    }

    func collectionView(_ collectionView: NSCollectionView, didEndDisplaying item: NSCollectionViewItem, forRepresentedObjectAt indexPath: IndexPath) {
        (item as? TabBarViewItem)?.clear()
    }

}

// MARK: - NSCollectionViewDelegate

extension TabBarViewController: NSCollectionViewDelegate {

    func collectionView(_ collectionView: NSCollectionView,
                        didChangeItemsAt indexPaths: Set<IndexPath>,
                        to highlightState: NSCollectionViewItem.HighlightState) {
        guard indexPaths.count == 1, let indexPath = indexPaths.first else {
            assertionFailure("TabBarViewController: More than 1 item highlighted")
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

    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        TabBarViewItemPasteboardWriter()
    }

    func collectionView(_ collectionView: NSCollectionView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forItemsAt indexPaths: Set<IndexPath>) {
        session.animatesToStartingPositionsOnCancelOrFail = false

        assert(indexPaths.count == 1, "TabBarViewController: More than 1 dragging index path")
        guard let indexPath = indexPaths.first else { return }

        TabDragAndDropManager.shared.setSource(tabCollectionViewModel: tabCollectionViewModel, index: indexPath.item)
        hideTabPreview()
    }

    private static let dropToOpenDistance: CGFloat = 100

    func collectionView(_ collectionView: NSCollectionView, validateDrop draggingInfo: NSDraggingInfo, proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>, dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {

        // allow dropping URLs or files
        guard draggingInfo.draggingPasteboard.url == nil else { return .copy }

        // Check if the pasteboard contains string data
        if draggingInfo.draggingPasteboard.availableType(from: [.string]) != nil {
            return .copy
        }

        // dragging a tab
        guard case .private = draggingInfo.draggingSourceOperationMask,
              draggingInfo.draggingPasteboard.types == [TabBarViewItemPasteboardWriter.utiInternalType] else { return .none }

        // move tab within one window if needed
        moveItemIfNeeded(to: proposedDropIndexPath.pointee.item)

        return .private
    }

    func collectionView(_ collectionView: NSCollectionView, acceptDrop draggingInfo: NSDraggingInfo, indexPath: IndexPath, dropOperation: NSCollectionView.DropOperation) -> Bool {
        let newIndex = min(indexPath.item + 1, tabCollectionViewModel.tabCollection.tabs.count)
        if let url = draggingInfo.draggingPasteboard.url {
            // dropping URL or file
            tabCollectionViewModel.insert(Tab(content: .url(url, source: .appOpenUrl), burnerMode: tabCollectionViewModel.burnerMode),
                                          at: .unpinned(newIndex),
                                          selected: true)
            return true
        } else if let string = draggingInfo.draggingPasteboard.string(forType: .string), let url = URL.makeURL(from: string) {
            tabCollectionViewModel.insertOrAppendNewTab(.url(url, credential: nil, source: .appOpenUrl))
            return true
        }

        guard case .private = draggingInfo.draggingSourceOperationMask,
              draggingInfo.draggingPasteboard.types == [TabBarViewItemPasteboardWriter.utiInternalType] else { return false }

        // update drop destination
        TabDragAndDropManager.shared.setDestination(tabCollectionViewModel: tabCollectionViewModel, index: newIndex)

        return true
    }

    func collectionView(_ collectionView: NSCollectionView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint, dragOperation operation: NSDragOperation) {

        // dropping a tab, dropping of url handled in collectionView:acceptDrop:
        guard session.draggingPasteboard.types == [TabBarViewItemPasteboardWriter.utiInternalType] else { return }

        // Don't allow drag and drop from Burner Window
        guard !tabCollectionViewModel.burnerMode.isBurner else { return }

        defer {
            TabDragAndDropManager.shared.clear()
        }
        if case .private = operation {
            // Perform the drag and drop between multiple windows
            TabDragAndDropManager.shared.performDragAndDropIfNeeded()
            DispatchQueue.main.async {
                self.collectionView.scrollToSelected()
            }
            return
        }
        // dropping not on a tab bar
        guard case .none = operation else { return }

        // Create a new window if the drop is too distant
        let frameRelativeToWindow = view.convert(view.bounds, to: nil)
        guard TabDragAndDropManager.shared.sourceUnit?.tabCollectionViewModel === tabCollectionViewModel,
              let sourceIndex = TabDragAndDropManager.shared.sourceUnit?.index,
              let frameRelativeToScreen = view.window?.convertToScreen(frameRelativeToWindow),
              !screenPoint.isNearRect(frameRelativeToScreen, allowedDistance: Self.dropToOpenDistance) else {
            // dropped near the tab bar, do nothing
            return
        }

        moveToNewWindow(from: sourceIndex,
                        droppingPoint: screenPoint,
                        burner: tabCollectionViewModel.isBurner)
    }

    func collectionView(_ collectionView: NSCollectionView,
                        layout collectionViewLayout: NSCollectionViewLayout,
                        referenceSizeForFooterInSection section: Int) -> NSSize {
        if tabMode == .overflow {
            return .zero
        } else {
            let width = footerCurrentWidthDimension
            return NSSize(width: width, height: collectionView.frame.size.height)
        }
    }

}

// MARK: - TabBarViewItemDelegate

extension TabBarViewController: TabBarViewItemDelegate {

    func tabBarViewItem(_ tabBarViewItem: TabBarViewItem, isMouseOver: Bool) {

        if isMouseOver {
            // Show tab preview for visible tab bar items
            if collectionView.visibleRect.intersects(tabBarViewItem.view.frame) {
                showTabPreview(for: tabBarViewItem)
            }
        } else {
            tabPreviewWindowController.hide(allowQuickRedisplay: true, withDelay: true)
        }
    }

    func tabBarViewItemCanBeDuplicated(_ tabBarViewItem: TabBarViewItem) -> Bool {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            assertionFailure("TabBarViewController: Failed to get index path of tab bar view item")
            return false
        }

        return tabCollectionViewModel.tabViewModel(at: indexPath.item)?.tab.content.canBeDuplicated ?? false
    }

    func tabBarViewItemDuplicateAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            assertionFailure("TabBarViewController: Failed to get index path of tab bar view item")
            return
        }

        duplicateTab(at: .unpinned(indexPath.item))
    }

    func tabBarViewItemCanBePinned(_ tabBarViewItem: TabBarViewItem) -> Bool {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            assertionFailure("TabBarViewController: Failed to get index path of tab bar view item")
            return false
        }

        return tabCollectionViewModel.tabViewModel(at: indexPath.item)?.tab.content.canBePinned ?? false
    }

    func tabBarViewItemPinAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            assertionFailure("TabBarViewController: Failed to get index path of tab bar view item")
            return
        }

        collectionView.clearSelection()
        tabCollectionViewModel.pinTab(at: indexPath.item)
    }

    func tabBarViewItemCanBeBookmarked(_ tabBarViewItem: TabBarViewItem) -> Bool {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            assertionFailure("TabBarViewController: Failed to get index path of tab bar view item")
            return false
        }

        return tabCollectionViewModel.tabViewModel(at: indexPath.item)?.tab.content.canBeBookmarked ?? false
    }

    func tabBarViewItemIsAlreadyBookmarked(_ tabBarViewItem: TabBarViewItem) -> Bool {
        guard let url = urlAndTitle(for: tabBarViewItem)?.url else { return false }

        return bookmarkManager.isUrlBookmarked(url: url)
    }

    func tabBarViewItemBookmarkThisPageAction(_ tabBarViewItem: TabBarViewItem) {
        guard let (url, title) = urlAndTitle(for: tabBarViewItem) else { return }

        bookmarkTab(with: url, title: title)
    }

    func tabBarViewItemRemoveBookmarkAction(_ tabBarViewItem: TabBarViewItem) {
        guard let url = urlAndTitle(for: tabBarViewItem)?.url else { return }

        deleteBookmark(with: url)
    }

    func tabBarViewAllItemsCanBeBookmarked(_ tabBarViewItem: TabBarViewItem) -> Bool {
        tabCollectionViewModel.canBookmarkAllOpenTabs()
    }

    func tabBarViewItemBookmarkAllOpenTabsAction(_ tabBarViewItem: TabBarViewItem) {
        let websitesInfo = tabCollectionViewModel.tabs.compactMap(WebsiteInfo.init)
        BookmarksDialogViewFactory.makeBookmarkAllOpenTabsView(websitesInfo: websitesInfo).show()
    }

    func tabBarViewItemCloseAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            assertionFailure("TabBarViewController: Failed to get index path of tab bar view item")
            return
        }

        tabCollectionViewModel.remove(at: .unpinned(indexPath.item))
    }

    func tabBarViewItemTogglePermissionAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem),
              let permissions = tabCollectionViewModel.tabViewModel(at: indexPath.item)?.tab.permissions
        else {
            assertionFailure("TabBarViewController: Failed to get index path of tab bar view item or its permissions")
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
            assertionFailure("TabBarViewController: Failed to get index path of tab bar view item")
            return
        }

        tabCollectionViewModel.removeAllTabs(except: indexPath.item)
    }

    func tabBarViewItemCloseToTheLeftAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            assertionFailure("TabBarViewController: Failed to get index path of tab bar view item")
            return
        }

        tabCollectionViewModel.removeTabs(before: indexPath.item)
    }

    func tabBarViewItemCloseToTheRightAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            assertionFailure("TabBarViewController: Failed to get index path of tab bar view item")
            return
        }

        tabCollectionViewModel.removeTabs(after: indexPath.item)
    }

    func tabBarViewItemMoveToNewWindowAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            assertionFailure("TabBarViewController: Failed to get index path of tab bar view item")
            return
        }

        moveToNewWindow(from: indexPath.item, burner: false)
    }

    func tabBarViewItemMoveToNewBurnerWindowAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            assertionFailure("TabBarViewController: Failed to get index path of tab bar view item")
            return
        }

        moveToNewWindow(from: indexPath.item, burner: true)
    }

    func tabBarViewItemFireproofSite(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem),
              let tab = tabCollectionViewModel.tabCollection.tabs[safe: indexPath.item]
        else {
            assertionFailure("TabBarViewController: Failed to get tab from tab bar view item")
            return
        }

        fireproof(tab)
    }

    func tabBarViewItemMuteUnmuteSite(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem),
              let tab = tabCollectionViewModel.tabCollection.tabs[safe: indexPath.item]
        else {
            assertionFailure("TabBarViewController: Failed to get tab from tab bar view item")
            return
        }

        tab.muteUnmuteTab()
    }

    func tabBarViewItemRemoveFireproofing(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem),
              let tab = tabCollectionViewModel.tabCollection.tabs[safe: indexPath.item]
        else {
            assertionFailure("TabBarViewController: Failed to get tab from tab bar view item")
            return
        }

        removeFireproofing(from: tab)
    }

    func tabBarViewItem(_ tabBarViewItem: TabBarViewItem, replaceContentWithDroppedStringValue stringValue: String) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem),
              let tab = tabCollectionViewModel.tabCollection.tabs[safe: indexPath.item] else { return }

        if let url = URL.makeURL(from: stringValue) {
            tab.setContent(.url(url, credential: nil, source: .userEntered(stringValue, downloadRequested: false)))
        }
    }

    func otherTabBarViewItemsState(for tabBarViewItem: TabBarViewItem) -> OtherTabBarViewItemsState {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            assertionFailure("TabBarViewController: Failed to get index path of tab bar view item")
            return .init(hasItemsToTheLeft: false, hasItemsToTheRight: false)
        }
        return .init(hasItemsToTheLeft: indexPath.item > 0,
                     hasItemsToTheRight: indexPath.item + 1 < tabCollectionViewModel.tabCollection.tabs.count)
    }

}

extension TabBarViewController {

    func startFireButtonPulseAnimation() {
        ViewHighlighter.highlight(view: fireButton, inParent: view)
    }

    func stopFireButtonPulseAnimation() {
        ViewHighlighter.stopHighlighting(view: fireButton)
    }

}

// MARK: - TabBarViewItemPasteboardWriter

final class TabBarViewItemPasteboardWriter: NSObject, NSPasteboardWriting {

    static let utiInternalType = NSPasteboard.PasteboardType(rawValue: "com.duckduckgo.tab.internal")

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        [Self.utiInternalType]
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        [String: Any]()
    }

}
