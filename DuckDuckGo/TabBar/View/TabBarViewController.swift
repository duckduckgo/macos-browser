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

    enum HorizontalSpace: CGFloat {
        case scrollViewPaddingWithButtons = 112
        case scrollViewPaddingWithoutButtons = 80
        case button = 32
        case buttonPadding = 8
    }

    @IBOutlet weak var collectionView: TabBarCollectionView!
    @IBOutlet weak var scrollView: TabBarScrollView!
    @IBOutlet weak var scrollViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var rightScrollButton: MouseOverButton!
    @IBOutlet weak var leftScrollButton: MouseOverButton!
    @IBOutlet weak var rightShadowImageView: NSImageView!
    @IBOutlet weak var leftShadowImageView: NSImageView!
    @IBOutlet weak var plusButton: MouseOverButton!
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

        scrollView.updateScrollElasticity(with: tabMode)
        observeToScrollNotifications()
        subscribeToSelectionIndex()
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        updateEmptyTabArea()
        tabCollectionViewModel.delegate = self
        reloadSelection()
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        updateTabMode(for: collectionView.numberOfItems(inSection: 0))
        updateEmptyTabArea()
        collectionView.invalidateLayout()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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
        plusButton.isHidden = isAddButtonFloating
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
    }

    private func moveToNewWindow(indexPath: IndexPath) {
        guard tabCollectionViewModel.tabCollection.tabs.count > 1 else { return }
        guard let tabViewModel = tabCollectionViewModel.tabViewModel(at: indexPath.item) else {
            os_log("TabBarViewController: Failed to get tab view model", type: .error)
            return
        }

        let url = tabViewModel.tab.url
        tabCollectionViewModel.remove(at: indexPath.item)
        WindowsManager.openNewWindow(with: url)
    }

    // MARK: - Tab Width

    enum TabMode {
        case divided
        case overflow
    }

    private var tabMode = TabMode.divided {
        didSet {
            if oldValue != tabMode {
                scrollView.updateScrollElasticity(with: tabMode)
                displayScrollButtons()
                updateEmptyTabArea()
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
        let horizontalSpace = tabMode == .divided ?
            HorizontalSpace.scrollViewPaddingWithoutButtons.rawValue :
            HorizontalSpace.scrollViewPaddingWithButtons.rawValue
        scrollViewLeadingConstraint.constant = horizontalSpace
        scrollViewTrailingConstraint.constant = horizontalSpace

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
        point.x += scrollViewLeadingConstraint.constant + tabBarViewItem.view.frame.origin.x - clipView.bounds.origin.x
        let converted = window.convertPoint(toScreen: view.convert(point, to: nil))
        tooltipWindowController.scheduleShowing(parentWindow: window, topLeftPoint: converted)
    }

    func hideTooltip() {
        tooltipWindowController.hide()
    }

}

extension TabBarViewController: TabCollectionViewModelDelegate {

    func tabCollectionViewModelDidAppend(_ tabCollectionViewModel: TabCollectionViewModel, selected: Bool) {
        appendToCollectionView(selected: selected)
    }

    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel, didInsertAndSelectAt index: Int) {
        let indexPathSet = Set(arrayLiteral: IndexPath(item: index))
        collectionView.clearSelection(animated: true)
        collectionView.animator().insertItems(at: indexPathSet)
        collectionView.selectItems(at: indexPathSet, scrollPosition: .centeredHorizontally)

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

        let shouldScroll = collectionView.isAtEndScrollPosition
        collectionView.animator().performBatchUpdates {
            if shouldScroll {
                collectionView.animator().scroll(CGPoint(x: scrollView.contentView.bounds.origin.x - currentTabWidth(), y: 0))
            }

            if collectionView.selectionIndexPaths != selectionIndexPathSet {
                collectionView.clearSelection()
                collectionView.animator().selectItems(at: selectionIndexPathSet, scrollPosition: .centeredHorizontally)
            }
            collectionView.animator().deleteItems(at: removedIndexPathSet)
        } completionHandler: { [weak self] _ in
            self?.updateTabMode()
            self?.updateEmptyTabArea()
            self?.enableScrollButtons()
            self?.hideTooltip()
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
        initialDraggingIndexPaths = indexPaths

        guard let indexPath = indexPaths.first, indexPaths.count == 1 else {
            os_log("TabBarViewController: More than 1 dragging index path", type: .error)
            return
        }
        currentDraggingIndexPath = indexPath
    }

    static let dropToOpenDistance: CGFloat = 100

    func collectionView(_ collectionView: NSCollectionView,
                        draggingSession session: NSDraggingSession,
                        endedAt screenPoint: NSPoint,
                        dragOperation operation: NSDragOperation) {
        let draggingIndexPath = self.currentDraggingIndexPath
        self.initialDraggingIndexPaths = nil
        currentDraggingIndexPath = nil

        // Create a new window if the drop is too distant from tab bar
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
            moveToNewWindow(indexPath: draggingIndexPath)
        }
    }

    func collectionView(_ collectionView: NSCollectionView,
                        validateDrop draggingInfo: NSDraggingInfo,
                        proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
                        dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        guard let currentDraggingIndexPath = currentDraggingIndexPath else {
            os_log("TabBarViewController: Current dragging index path is nil", type: .error)
            return .copy
        }

        let newIndexPath = proposedDropIndexPath.pointee as IndexPath
        moveItemIfNeeded(at: currentDraggingIndexPath, to: newIndexPath)

        proposedDropOperation.pointee = .before
        return .move
    }

    func collectionView(_ collectionView: NSCollectionView,
                        acceptDrop draggingInfo: NSDraggingInfo,
                        indexPath: IndexPath,
                        dropOperation: NSCollectionView.DropOperation) -> Bool {
        guard let draggingIndexPaths = initialDraggingIndexPaths else {
            os_log("TabBarViewController: Dragging index paths is nil", type: .error)
            return false
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

    func tabBarViewItemCloseAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            os_log("TabBarViewController: Failed to get index path of tab bar view item", type: .error)
            return
        }

        tabCollectionViewModel.remove(at: indexPath.item)
    }

    func tabBarViewItemCloseOtherAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            os_log("TabBarViewController: Failed to get index path of tab bar view item", type: .error)
            return
        }

        tabCollectionViewModel.removeAllTabs(except: indexPath.item)
    }

    func tabBarViewItemMoveToNewWindowAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            os_log("TabBarViewController: Failed to get index path of tab bar view item", type: .error)
            return
        }

        moveToNewWindow(indexPath: indexPath)
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
