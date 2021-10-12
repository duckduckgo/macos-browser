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
import GRDB

final class FirePopoverViewController: NSViewController {

    private let fireViewModel: FireViewModel
    private let tabCollectionViewModel: TabCollectionViewModel
    private var clearingOption: FireClearingOption = .allData {
        didSet {
            updateCloseDetailsButton()
            updateDomainList()
        }
    }
    private var domainList: FireDomainList = FireDomainList.empty {
        didSet {
            collectionView.reloadData()
            selectClearSection()
        }
    }
    private let historyCoordinating: HistoryCoordinating

    @IBOutlet weak var optionsButton: NSPopUpButton!
    @IBOutlet weak var openDetailsButton: NSButton!
    @IBOutlet weak var closeDetailsButton: NSButton!
    @IBOutlet weak var detailsWrapperView: NSView!
    @IBOutlet weak var contentSizeConstraint: NSLayoutConstraint!
    @IBOutlet weak var collectionView: NSCollectionView!

    required init?(coder: NSCoder) {
        fatalError("FirePopoverViewController: Bad initializer")
    }

    init?(coder: NSCoder, fireViewModel: FireViewModel,
          tabCollectionViewModel: TabCollectionViewModel,
          historyCoordinating: HistoryCoordinating = HistoryCoordinator.shared) {
        self.fireViewModel = fireViewModel
        self.tabCollectionViewModel = tabCollectionViewModel
        self.historyCoordinating = historyCoordinating

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let nib = NSNib(nibNamed: "FirePopoverCollectionViewItem", bundle: nil)
        collectionView.register(nib, forItemWithIdentifier: FirePopoverCollectionViewItem.identifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        setupOptionsButton()
        updateCloseDetailsButton()
        updateDomainList()
    }

    private func setupOptionsButton() {
        FireClearingOption.allCases.enumerated().forEach { (index, option) in
            optionsButton.menu?.item(withTag: index)?.title = option.string
        }
    }

    @IBAction func optionsButtonAction(_ sender: NSPopUpButton) {
        guard let tag = sender.selectedItem?.tag else {
            assertionFailure("No tag in the selected menu item")
            return
        }
        clearingOption = FireClearingOption.allCases[tag]
    }

    @IBAction func openDetailsButtonAction(_ sender: Any) {
        toggleDetails()
    }

    @IBAction func closeDetailsButtonAction(_ sender: Any) {
        toggleDetails()
    }

    private func updateCloseDetailsButton() {
        switch clearingOption {
        case .currentTab: closeDetailsButton.title = UserText.currentTabDescription
        case .currentWindow: closeDetailsButton.title = UserText.currentWindowDescription
        case .allData: closeDetailsButton.title = UserText.allDataDescription
        }
    }

    @IBAction func clearButtonAction(_ sender: Any) {
        let timedPixel = TimedPixel(.burn())
        fireViewModel.fire.burnAll(tabCollectionViewModel: tabCollectionViewModel) { timedPixel.fire() }
    }

    @IBAction func cancelButtonAction(_ sender: Any) {
        dismiss()
    }

    private func toggleDetails() {
        let showDetails = detailsWrapperView.isHidden
        openDetailsButton.isHidden = showDetails
        detailsWrapperView.isHidden = !showDetails

        NSAnimationContext.runAnimationGroup { [weak self] context in
            context.duration = 1/3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self?.contentSizeConstraint.animator().constant = showDetails ? 263 : 42
        }
    }

    private func updateDomainList() {
        switch clearingOption {
        case .currentTab:
            guard let tab = tabCollectionViewModel.selectedTabViewModel?.tab else {
                assertionFailure("selectedTabViewModel is nil")
                return
            }

            domainList = FireDomainList(tab: tab)
        case .currentWindow:
            domainList =  FireDomainList(tabCollection: tabCollectionViewModel.tabCollection)
        case .allData:
            domainList = FireDomainList(historyCoordinating: historyCoordinating)
        }
    }

    private func selectClearSection() {
        let indexPaths = Set((0..<domainList.selectable.count).map { IndexPath(item: $0, section: 1) })
        collectionView.selectItems(at: indexPaths, scrollPosition: [])
    }

}

extension FirePopoverViewController: NSCollectionViewDataSource {

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 2
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? domainList.fireproofed.count : domainList.selectable.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: FirePopoverCollectionViewItem.identifier, for: indexPath)
        guard let firePopoverItem = item as? FirePopoverCollectionViewItem else { return item }

        firePopoverItem.delegate = self
        let sectionList = (indexPath.section == 0 ? domainList.fireproofed : domainList.selectable)
        let listItem = sectionList[indexPath.item]
        firePopoverItem.setItem(listItem, isFireproofed: indexPath.section == 0)
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

        if indexPath.section == 0 {
            view.title.stringValue = UserText.fireDialogFireproofSites
        } else {
            view.title.stringValue = UserText.fireDialogClearSites
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
        case 0: count = domainList.fireproofed.count
        case 1: count = domainList.selectable.count
        default: count = 0
        }
        return NSSize(width: collectionView.bounds.width, height: count == 0 ? 0 : 28)
    }

}

extension FirePopoverViewController: FirePopoverCollectionViewItemDelegate {

    func firePopoverCollectionViewItemDidToggle(_ firePopoverCollectionViewItem: FirePopoverCollectionViewItem) {
        guard let indexPath = collectionView.indexPath(for: firePopoverCollectionViewItem) else {
            assertionFailure("No index path for the \(firePopoverCollectionViewItem)")
            return
        }

        if firePopoverCollectionViewItem.isSelected {
            collectionView.deselectItems(at: [indexPath])
        } else {
            collectionView.selectItems(at: [indexPath], scrollPosition: [])
        }
    }

}
