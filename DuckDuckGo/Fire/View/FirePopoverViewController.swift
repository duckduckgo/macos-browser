//
//  FirePopoverViewController.swift
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

import Cocoa
import Combine
import Common
import History
import os.log

protocol FirePopoverViewControllerDelegate: AnyObject {

    func firePopoverViewControllerDidClear(_ firePopoverViewController: FirePopoverViewController)
    func firePopoverViewControllerDidCancel(_ firePopoverViewController: FirePopoverViewController)

}

final class FirePopoverViewController: NSViewController {

    struct Constants {
        static let maximumContentHeight: CGFloat = 42 + 230 + 32
        static let minimumContentHeight: CGFloat = 42
        static let headerHeight: CGFloat = 28
        static let footerHeight: CGFloat = 8
    }

    weak var delegate: FirePopoverViewControllerDelegate?

    private let fireViewModel: FireViewModel
    private var firePopoverViewModel: FirePopoverViewModel
    private let historyCoordinating: HistoryCoordinating

    @IBOutlet weak var closeTabsLabel: NSTextField!
    @IBOutlet weak var openFireWindowsTitleLabel: NSTextField!
    @IBOutlet weak var fireWindowDescriptionLabel: NSTextField!
    @IBOutlet weak var headerWrapperView: NSView!
    @IBOutlet weak var mainButtonsToBurnerWindowContraint: NSLayoutConstraint!
    @IBOutlet weak var infoLabel: NSTextField!
    @IBOutlet weak var optionsButton: NSPopUpButton!
    @IBOutlet weak var optionsButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var openDetailsButton: NSButton!
    @IBOutlet weak var openDetailsButtonImageView: NSImageView!
    @IBOutlet weak var closeDetailsButton: NSButton!
    @IBOutlet weak var detailsWrapperView: NSView!
    @IBOutlet weak var contentHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var detailsWrapperViewHeightContraint: NSLayoutConstraint!
    @IBOutlet weak var openWrapperView: NSView!
    @IBOutlet weak var closeWrapperView: NSView!
    @IBOutlet weak var collectionView: NSCollectionView!
    @IBOutlet weak var collectionViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var warningWrapperView: NSView!
    @IBOutlet weak var warningButton: NSButton!
    @IBOutlet weak var clearButton: NSButton!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var closeBurnerWindowButton: NSButton!

    private var viewModelCancellable: AnyCancellable?
    private var selectedCancellable: AnyCancellable?

    required init?(coder: NSCoder) {
        fatalError("FirePopoverViewController: Bad initializer")
    }

    init?(coder: NSCoder,
          fireViewModel: FireViewModel,
          tabCollectionViewModel: TabCollectionViewModel,
          historyCoordinating: HistoryCoordinating = HistoryCoordinator.shared,
          fireproofDomains: FireproofDomains = FireproofDomains.shared,
          faviconManagement: FaviconManagement = FaviconManager.shared) {
        self.fireViewModel = fireViewModel
        self.historyCoordinating = historyCoordinating
        self.firePopoverViewModel = FirePopoverViewModel(fireViewModel: fireViewModel,
                                                         tabCollectionViewModel: tabCollectionViewModel,
                                                         historyCoordinating: historyCoordinating,
                                                         fireproofDomains: fireproofDomains,
                                                         faviconManagement: faviconManagement,
                                                         tld: ContentBlocking.shared.tld,
                                                         contextualOnboardingStateMachine: Application.appDelegate.onboardingStateMachine)

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let nib = NSNib(nibNamed: "FirePopoverCollectionViewItem", bundle: nil)
        collectionView.register(nib, forItemWithIdentifier: FirePopoverCollectionViewItem.identifier)
        collectionView.delegate = self
        collectionView.dataSource = self

        if firePopoverViewModel.tabCollectionViewModel?.isBurner ?? false {
            adjustViewForBurnerWindow()
            return
        }

        setUpStrings()
        updateClearButtonAppearance()
        setupOptionsButton()
        setupOpenCloseDetailsButton()
        updateWarningWrapperView()

        subscribeToViewModel()
        subscribeToSelected()
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        firePopoverViewModel.refreshItems()
    }

    private func setUpStrings() {
        openFireWindowsTitleLabel.stringValue = UserText.fireDialogFireWindowTitle
        fireWindowDescriptionLabel.stringValue = UserText.fireDialogFireWindowDescription
        closeTabsLabel.stringValue = UserText.fireDialogCloseTabs
        closeBurnerWindowButton.title = UserText.fireDialogBurnWindowButton
        clearButton.title = UserText.clear
        cancelButton.title = UserText.cancel
    }

    @IBAction func optionsButtonAction(_ sender: NSPopUpButton) {
        guard let tag = sender.selectedItem?.tag, let clearingOption = FirePopoverViewModel.ClearingOption(rawValue: tag) else {
            assertionFailure("Clearing option for not found for the selected menu item")
            return
        }
        firePopoverViewModel.clearingOption = clearingOption
        updateWarningWrapperView()
    }

    @IBAction func openNewBurnerWindowAction(_ sender: Any) {
        NSApp.delegateTyped.newBurnerWindow(self)
    }

    @IBAction func openDetailsButtonAction(_ sender: Any) {
        toggleDetails()
    }

    @IBAction func closeDetailsButtonAction(_ sender: Any) {
        toggleDetails()
    }

    @IBAction func closeBurnerWindowButtonAction(_ sender: Any) {
        let windowControllersManager = WindowControllersManager.shared
        guard let tabCollectionViewModel = firePopoverViewModel.tabCollectionViewModel,
              let windowController = windowControllersManager.windowController(for: tabCollectionViewModel) else {
            assertionFailure("No TabCollectionViewModel or MainWindowController")
            return
        }
        windowController.window?.performClose(self)
    }

    private func adjustViewForBurnerWindow() {
        updateCloseBurnerWindowButtonAppearance()
        clearButton.isHidden = true
        cancelButton.isHidden = true
        closeBurnerWindowButton.isHidden = false

        contentHeightConstraint.isActive = false
        headerWrapperView.isHidden = true
        openWrapperView.isHidden = true
        detailsWrapperView.isHidden = true
        warningWrapperView.isHidden = true
        mainButtonsToBurnerWindowContraint.priority = .required
    }

    private func updateInfoLabel() {
        guard !firePopoverViewModel.selectable.isEmpty else {
            infoLabel.stringValue = ""
            return
        }

        guard !firePopoverViewModel.selected.isEmpty else {
            infoLabel.stringValue = UserText.selectSiteToClear
            return
        }

        let sites = firePopoverViewModel.selected.count
        switch firePopoverViewModel.clearingOption {
        case .allData:
            let tabs = WindowControllersManager.shared.allTabViewModels.count
            infoLabel.stringValue = UserText.activeTabsInfo(tabs: tabs, sites: sites)
        case .currentWindow:
            let tabs = firePopoverViewModel.tabCollectionViewModel?.tabs.count ?? 0
            infoLabel.stringValue = UserText.activeTabsInfo(tabs: tabs, sites: sites)
        case .currentTab:
            infoLabel.stringValue = UserText.oneTabInfo(sites: sites)
        }
    }

    private func updateClearButtonAppearance() {
        setRedTintColor(button: clearButton)
    }

    private func updateCloseBurnerWindowButtonAppearance() {
        setRedTintColor(button: closeBurnerWindowButton)
    }

    private func setRedTintColor(button: NSButton) {
        let attrTitle = NSMutableAttributedString(string: button.title)
        let range = NSRange(location: 0, length: button.title.count)

        attrTitle.addAttributes([
            .foregroundColor: NSColor.redButtonTint,
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)],
            range: range)

        button.attributedTitle = attrTitle
    }

    private func setupOpenCloseDetailsButton() {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = 15
        let title = NSMutableAttributedString(string: UserText.fireDialogDetails)
        title.addAttributes([.paragraphStyle: paragraphStyle], range: NSRange(location: 0, length: title.length))

        openDetailsButton.attributedTitle = title
        openDetailsButton.alignment = .left
        closeDetailsButton.attributedTitle = title
        closeDetailsButton.alignment = .left
    }

    private func updateWarningWrapperView() {
        warningWrapperView.isHidden = detailsWrapperView.isHidden

        if !warningWrapperView.isHidden {
            let title: String
            switch firePopoverViewModel.clearingOption {
            case .currentTab:
                if firePopoverViewModel.tabCollectionViewModel?.selectedTab?.isPinned ?? false {
                    title = UserText.fireDialogPinnedTabWillReload
                } else {
                    title = UserText.fireDialogTabWillClose
                }
            case .currentWindow:
                title = UserText.fireDialogWindowWillClose
            case .allData:
                title = UserText.fireDialogAllWindowsWillClose
            }

            warningButton.title = "   \(title)"
        }

        collectionViewBottomConstraint.constant = warningWrapperView.isHidden ? 0 : 32
    }

    @IBAction func clearButtonAction(_ sender: Any) {
        delegate?.firePopoverViewControllerDidClear(self)
        firePopoverViewModel.burn()

    }

    @IBAction func cancelButtonAction(_ sender: Any) {
        delegate?.firePopoverViewControllerDidCancel(self)
    }

    private func subscribeToViewModel() {
        viewModelCancellable = Publishers.Zip(
            firePopoverViewModel.$fireproofed,
            firePopoverViewModel.$selectable
        ).receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.collectionView.reloadData()
                if self.firePopoverViewModel.selectable.isEmpty && !self.detailsWrapperView.isHidden {
                    self.toggleDetails()
                }
                self.updateInfoLabel()
                self.adjustContentHeight()
            }
    }

    private func subscribeToSelected() {
        selectedCancellable = firePopoverViewModel.$selected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selected in
                guard let self = self else { return }
                let selectionIndexPaths = Set(selected.map {IndexPath(item: $0, section: self.firePopoverViewModel.selectableSectionIndex)})
                self.collectionView.selectionIndexPaths = selectionIndexPaths
                self.updateInfoLabel()
            }
    }

    private func toggleDetails() {
        let showDetails = detailsWrapperView.isHidden
        openWrapperView.isHidden = showDetails
        detailsWrapperView.isHidden = !showDetails

        updateWarningWrapperView()
        adjustContentHeight()
    }

    private func adjustContentHeight() {
        NSAnimationContext.runAnimationGroup { [self, contentHeight = contentHeight()] context in
            context.duration = 1/3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.contentHeightConstraint.animator().constant = contentHeight
            if contentHeight != Constants.minimumContentHeight {
                self.detailsWrapperViewHeightContraint.animator().constant = contentHeight
            }
        }
    }

    private func contentHeight() -> CGFloat {
        if detailsWrapperView.isHidden {
            return Constants.minimumContentHeight
        } else {
            if let contentHeight = collectionView.collectionViewLayout?.collectionViewContentSize.height {
                let warningWrapperViewHeight = warningWrapperView.isHidden ? 0 : warningWrapperView.frame.height
                let height = contentHeight + closeWrapperView.frame.height + warningWrapperViewHeight
                return min(Constants.maximumContentHeight, height)
            } else {
                return Constants.maximumContentHeight
            }
        }
    }

    private func setupOptionsButton() {
        guard let menu = optionsButton.menu, let font = optionsButton.font else {
            Logger.fire.error("FirePopoverViewController: Menu and/or font not present for optionsMenu")
            return
        }
        menu.removeAllItems()

        let constraintSize = NSSize(width: .max, height: 0)
        let attributes = [NSAttributedString.Key.font: font]
        var maxWidth: CGFloat = 0

        FirePopoverViewModel.ClearingOption.allCases.forEach { option in
            if option == .allData {
                menu.addItem(.separator())
            }

            let item = NSMenuItem(title: option.string)
            item.tag = option.rawValue
            menu.addItem(item)

            let width = (option.string as NSString)
                .boundingRect(with: constraintSize, options: .usesDeviceMetrics, attributes: attributes, context: nil)
                .width
            maxWidth = max(maxWidth, width)
        }

        optionsButtonWidthConstraint.constant = maxWidth + 32
        optionsButton.selectItem(at: optionsButton.numberOfItems - 1)
    }
}

extension FirePopoverViewController: NSCollectionViewDataSource {

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 2
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == firePopoverViewModel.selectableSectionIndex ? firePopoverViewModel.selectable.count: firePopoverViewModel.fireproofed.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: FirePopoverCollectionViewItem.identifier, for: indexPath)
        guard let firePopoverItem = item as? FirePopoverCollectionViewItem else { return item }

        firePopoverItem.delegate = self
        let isSelectableSection = indexPath.section == firePopoverViewModel.selectableSectionIndex
        let sectionList = isSelectableSection ? firePopoverViewModel.selectable: firePopoverViewModel.fireproofed
        let listItem = sectionList[indexPath.item]
        firePopoverItem.setItem(listItem, isFireproofed: indexPath.section == firePopoverViewModel.fireproofedSectionIndex)
        return firePopoverItem
    }

    func collectionView(_ collectionView: NSCollectionView,
                        viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind,
                        at indexPath: IndexPath) -> NSView {
        // swiftlint:disable force_cast
        let view = collectionView.makeSupplementaryView(ofKind: NSCollectionView.elementKindSectionHeader,
                                                        withIdentifier: FirePopoverCollectionViewHeader.identifier,
                                                        for: indexPath) as! FirePopoverCollectionViewHeader
        // swiftlint:enable force_cast

        if indexPath.section == firePopoverViewModel.selectableSectionIndex {
            view.title.stringValue = UserText.fireDialogClearSites
        } else {
            view.title.stringValue = UserText.fireDialogFireproofSites
        }

        return view
    }

}

extension FirePopoverViewController: NSCollectionViewDelegate {

}

extension FirePopoverViewController: NSCollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: NSCollectionView,
                        layout collectionViewLayout: NSCollectionViewLayout,
                        referenceSizeForHeaderInSection section: Int) -> NSSize {
        let count: Int
        switch section {
        case firePopoverViewModel.selectableSectionIndex: count = firePopoverViewModel.selectable.count
        case firePopoverViewModel.fireproofedSectionIndex: count = firePopoverViewModel.fireproofed.count
        default: count = 0
        }
        return NSSize(width: collectionView.bounds.width, height: count == 0 ? 0 : Constants.headerHeight)
    }

    func collectionView(_ collectionView: NSCollectionView,
                        layout collectionViewLayout: NSCollectionViewLayout,
                        referenceSizeForFooterInSection section: Int) -> NSSize {
        let count: Int
        switch section {
        case firePopoverViewModel.selectableSectionIndex: count = firePopoverViewModel.selectable.count
        case firePopoverViewModel.fireproofedSectionIndex: count = firePopoverViewModel.fireproofed.count
        default: count = 0
        }
        return NSSize(width: collectionView.bounds.width, height: count == 0 ? 0 : Constants.footerHeight)
    }

}

extension FirePopoverViewController: FirePopoverCollectionViewItemDelegate {

    func firePopoverCollectionViewItemDidToggle(_ firePopoverCollectionViewItem: FirePopoverCollectionViewItem) {
        guard let indexPath = collectionView.indexPath(for: firePopoverCollectionViewItem) else {
            assertionFailure("No index path for the \(firePopoverCollectionViewItem)")
            return
        }

        if firePopoverCollectionViewItem.isSelected {
            firePopoverViewModel.deselect(index: indexPath.item)
        } else {
            firePopoverViewModel.select(index: indexPath.item)
        }
    }

}
