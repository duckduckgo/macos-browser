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

    private lazy var viewMainButtonsWrapperView = ColorView(frame: .zero, backgroundColor: .interfaceBackground)
    private lazy var closeTabsLabel = NSTextField(string: UserText.fireDialogCloseTabs)
    private lazy var openFireWindowsTitleLabel = NSTextField(string: UserText.fireDialogFireWindowTitle)
    private lazy var fireWindowDescriptionLabel = NSTextField(string: UserText.fireDialogFireWindowDescription)
    private lazy var headerWrapperView = NSView()
    private lazy var infoLabel = NSTextField()
    private lazy var optionsButton = NSPopUpButton(title: UserText.allData, target: self, action: #selector(optionsButtonAction))
    private var optionsButtonWidthConstraint: NSLayoutConstraint!
    private lazy var openDetailsButton = MouseOverButton(title: "        " + UserText.details, target: self, action: #selector(openDetailsButtonAction))
    private lazy var openDetailsButtonImageView = NSImageView()
    private lazy var closeDetailsButton = MouseOverButton(title: "     " + UserText.fireDialogCloseAllTabsAndClear, target: self, action: #selector(closeDetailsButtonAction))
    private lazy var detailsWrapperView = NSView()
    private var contentHeightConstraint: NSLayoutConstraint!
    private var detailsWrapperViewHeightContraint: NSLayoutConstraint!
    private lazy var openWrapperView = NSView()
    private lazy var closeWrapperView = ColorView(frame: NSRect(x: 0, y: 0, width: 344, height: 42), backgroundColor: .firePopoverPanelBackground)
    private lazy var scrollView = NSScrollView()
    private lazy var collectionView = NSCollectionView()
    private var collectionViewBottomConstraint: NSLayoutConstraint!
    private lazy var warningWrapperView = ColorView(frame: NSRect(x: 0, y: 0, width: 344, height: 32), backgroundColor: .firePopoverPanelBackground)
    private lazy var warningButton = NSButton(image: .warningTriangle, target: nil, action: nil)
    private lazy var clearButton = NSButton(title: UserText.clear, target: self, action: #selector(clearButtonAction))
    private lazy var cancelButton = NSButton(title: UserText.cancel, target: self, action: #selector(cancelButtonAction))
    private var mainButtonsToBurnerWindowContraint: NSLayoutConstraint!
    private lazy var closeBurnerWindowButton = NSButton(title: UserText.fireDialogBurnWindowButton, target: self, action: #selector(closeBurnerWindowButtonAction))

    private var viewModelCancellable: AnyCancellable?
    private var selectedCancellable: AnyCancellable?

    required init?(coder: NSCoder) {
        fatalError("FirePopoverViewController: Bad initializer")
    }

    init(fireViewModel: FireViewModel,
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
                                                         tld: ContentBlocking.shared.tld)

        super.init(nibName: nil, bundle: nil)
    }

    override func loadView() {
        // MARK: Open New Fire Window (header)

        let openFireWindowContainerView = NSView()
        openFireWindowContainerView.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView(image: .burnerWindowButtonIcon)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentTintColor = .labelColor
        iconView.imageScaling = .scaleProportionallyDown
        iconView.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        iconView.setContentHuggingPriority(.init(rawValue: 251), for: .vertical)

        openFireWindowsTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        openFireWindowsTitleLabel.isEditable = false
        openFireWindowsTitleLabel.isBordered = false
        openFireWindowsTitleLabel.isSelectable = false
        openFireWindowsTitleLabel.drawsBackground = false
        openFireWindowsTitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        openFireWindowsTitleLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
        openFireWindowsTitleLabel.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        openFireWindowsTitleLabel.font = .systemFont(ofSize: 13)
        openFireWindowsTitleLabel.textColor = .labelColor

        fireWindowDescriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        fireWindowDescriptionLabel.isEditable = false
        fireWindowDescriptionLabel.isBordered = false
        fireWindowDescriptionLabel.isSelectable = false
        fireWindowDescriptionLabel.drawsBackground = false
        fireWindowDescriptionLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        fireWindowDescriptionLabel.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        fireWindowDescriptionLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        fireWindowDescriptionLabel.textColor = .secondaryLabelColor

        let fireWindowMouseOverButton = MouseOverButton(target: self, action: #selector(openNewBurnerWindowAction))
        fireWindowMouseOverButton.translatesAutoresizingMaskIntoConstraints = false
        fireWindowMouseOverButton.cornerRadius = 4
        fireWindowMouseOverButton.mouseDownColor = .buttonMouseDown
        fireWindowMouseOverButton.mouseOverColor = .buttonMouseOver

        openFireWindowContainerView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        openFireWindowContainerView.setContentHuggingPriority(.defaultHigh, for: .vertical)

        openFireWindowContainerView.addSubview(iconView)
        openFireWindowContainerView.addSubview(openFireWindowsTitleLabel)
        openFireWindowContainerView.addSubview(fireWindowDescriptionLabel)
        openFireWindowContainerView.addSubview(fireWindowMouseOverButton)

        // MARK: Header Image, Options View

        let headerSeparator = NSBox()
        headerSeparator.translatesAutoresizingMaskIntoConstraints = false
        headerSeparator.boxType = .separator
        headerSeparator.setContentHuggingPriority(.defaultHigh, for: .vertical)

        let fireHeaderImageView = NSImageView(image: .fireHeader)
        fireHeaderImageView.translatesAutoresizingMaskIntoConstraints = false
        fireHeaderImageView.imageScaling = .scaleProportionallyDown
        fireHeaderImageView.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        fireHeaderImageView.setContentHuggingPriority(.init(rawValue: 251), for: .vertical)

        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.isEditable = false
        infoLabel.isBordered = false
        infoLabel.isSelectable = false
        infoLabel.drawsBackground = false
        infoLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
        infoLabel.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        infoLabel.alignment = .center
        infoLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize,
                                     weight: .regular)
        infoLabel.textColor = .secondaryLabelColor

        optionsButton.translatesAutoresizingMaskIntoConstraints = false
        optionsButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        optionsButton.setContentHuggingPriority(.required, for: .horizontal)
        optionsButton.alignment = .center
        optionsButton.bezelStyle = .regularSquare
        optionsButton.font = .menuFont(ofSize: 13)
        optionsButton.lineBreakMode = .byTruncatingTail
        optionsButton.cell?.isBordered = true
        optionsButton.cell?.state = .on
        optionsButton.cell?.tag = 2

        closeTabsLabel.translatesAutoresizingMaskIntoConstraints = false
        closeTabsLabel.isEditable = false
        closeTabsLabel.isBordered = false
        closeTabsLabel.isSelectable = false
        closeTabsLabel.drawsBackground = false
        closeTabsLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
        closeTabsLabel.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        closeTabsLabel.font = .systemFont(ofSize: 13)
        closeTabsLabel.lineBreakMode = .byClipping
        closeTabsLabel.textColor = .labelColor

        headerWrapperView.translatesAutoresizingMaskIntoConstraints = false
        headerWrapperView.addSubview(headerSeparator)
        headerWrapperView.addSubview(fireHeaderImageView)
        headerWrapperView.addSubview(closeTabsLabel)
        headerWrapperView.addSubview(optionsButton)
        headerWrapperView.addSubview(infoLabel)

        // MARK: Open Details button

        openDetailsButtonImageView.translatesAutoresizingMaskIntoConstraints = false
        openDetailsButtonImageView.contentTintColor = .greyText
        openDetailsButtonImageView.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        openDetailsButtonImageView.setContentHuggingPriority(.init(rawValue: 251), for: .vertical)
        openDetailsButtonImageView.alignment = .left
        openDetailsButtonImageView.image = .expandDownPadding
        openDetailsButtonImageView.imageScaling = .scaleProportionallyDown

        openDetailsButton.translatesAutoresizingMaskIntoConstraints = false
        openDetailsButton.normalTintColor = .greyText
        openDetailsButton.alignment = .center
        openDetailsButton.bezelStyle = .shadowlessSquare
        openDetailsButton.font = .systemFont(ofSize: NSFont.smallSystemFontSize,
                                             weight: .regular)
        openDetailsButton.mouseDownColor = .buttonMouseDownColorLight
        openDetailsButton.mouseOverColor = .buttonMouseOverColorLight

        openWrapperView.translatesAutoresizingMaskIntoConstraints = false
        openWrapperView.addSubview(openDetailsButtonImageView)
        openWrapperView.addSubview(openDetailsButton)

        // MARK: Details (Collection View)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.horizontalLineScroll = 10
        scrollView.horizontalPageScroll = 10
        scrollView.usesPredominantAxisScrolling = false
        scrollView.verticalLineScroll = 10
        scrollView.verticalPageScroll = 10
        scrollView.wantsLayer = true

        let clipView = NSClipView()
        clipView.documentView = collectionView

        clipView.autoresizingMask = [.width, .height]
        clipView.backgroundColor = .interfaceBackground
        clipView.drawsBackground = false
        clipView.frame = CGRect(x: 0, y: 0, width: 344, height: 221)

        let collectionViewLayout = NSCollectionViewFlowLayout()
        collectionViewLayout.itemSize = CGSize(width: 318, height: 24)

        collectionView.collectionViewLayout = collectionViewLayout
        collectionView.allowsMultipleSelection = true
        collectionView.autoresizingMask = [.width]
        collectionView.backgroundColors = [.firePopoverListBackground]
        collectionView.frame = CGRect(x: 0, y: 0, width: 344, height: 221)
        collectionView.isSelectable = true

        scrollView.contentView = clipView

        detailsWrapperView.translatesAutoresizingMaskIntoConstraints = false
        detailsWrapperView.addSubview(scrollView)

        detailsWrapperView.isHidden = true

        // MARK: Close Details button

        let closeDetailsSeparator1 = NSBox(frame: CGRect(x: 0, y: 39, width: 344, height: 5))
        closeDetailsSeparator1.autoresizingMask = [.maxXMargin, .minYMargin]
        closeDetailsSeparator1.boxType = .separator
        closeDetailsSeparator1.setContentHuggingPriority(.defaultHigh, for: .vertical)

        let closeDetailsSeparator2 = NSBox(frame: CGRect(x: 0, y: -2, width: 344, height: 5))
        closeDetailsSeparator2.autoresizingMask = [.maxXMargin, .minYMargin]
        closeDetailsSeparator2.boxType = .separator
        closeDetailsSeparator2.setContentHuggingPriority(.defaultHigh, for: .vertical)

        closeDetailsButton.normalTintColor = .greyText
        closeDetailsButton.translatesAutoresizingMaskIntoConstraints = false
        closeDetailsButton.alignment = .left
        closeDetailsButton.bezelStyle = .shadowlessSquare
        closeDetailsButton.font = .systemFont(ofSize: NSFont.smallSystemFontSize,
                                              weight: .regular)
        closeDetailsButton.image = .condenseUpPadding
        closeDetailsButton.imagePosition = .imageTrailing
        closeDetailsButton.backgroundInset = CGPoint(x: -6, y: 0.0)
        closeDetailsButton.mouseDownColor = .buttonMouseDownColorLight
        closeDetailsButton.mouseOverColor = .buttonMouseOverColorLight

        closeWrapperView.translatesAutoresizingMaskIntoConstraints = false
        closeWrapperView.addSubview(closeDetailsSeparator1)
        closeWrapperView.addSubview(closeDetailsSeparator2)
        closeWrapperView.addSubview(closeDetailsButton)

        detailsWrapperView.addSubview(closeWrapperView)

        // MARK: Warning Wrapper View

        let warningSeparator1 = NSBox(frame: CGRect(x: 0, y: 29, width: 320, height: 5))
        warningSeparator1.autoresizingMask = [.maxXMargin, .minYMargin]
        warningSeparator1.boxType = .separator
        warningSeparator1.setContentHuggingPriority(.defaultHigh, for: .vertical)

        let warningSeparator2 = NSBox(frame: CGRect(x: 0, y: -12, width: 320, height: 5))
        warningSeparator2.autoresizingMask = [.maxXMargin, .minYMargin]
        warningSeparator2.boxType = .separator
        warningSeparator2.setContentHuggingPriority(.defaultHigh, for: .vertical)

        warningButton.autoresizingMask = [.maxXMargin, .minYMargin]
        warningButton.contentTintColor = .greyText
        warningButton.frame = CGRect(x: 20, y: 0, width: 304, height: 32)
        warningButton.alignment = .left
        warningButton.bezelStyle = .shadowlessSquare
        warningButton.isBordered = false
        warningButton.font = .systemFont(ofSize: NSFont.smallSystemFontSize,
                                         weight: .regular)
        warningButton.image = .warningTriangle
        warningButton.imagePosition = .imageLeading

        warningWrapperView.translatesAutoresizingMaskIntoConstraints = false
        warningWrapperView.addSubview(warningSeparator1)
        warningWrapperView.addSubview(warningSeparator2)
        warningWrapperView.addSubview(warningButton)

        // MARK: View Main Buttons (footer)

        let separator = NSBox()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.boxType = .separator
        separator.setContentHuggingPriority(.defaultHigh, for: .vertical)

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setContentHuggingPriority(.defaultHigh, for: .vertical)
        cancelButton.alignment = .center
        cancelButton.bezelStyle = .rounded
        cancelButton.controlSize = .large
        cancelButton.font = .systemFont(ofSize: 13)
        cancelButton.imageScaling = .scaleProportionallyDown
        cancelButton.cell?.isBordered = true

        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.setContentHuggingPriority(.defaultHigh, for: .vertical)
        clearButton.alignment = .center
        clearButton.bezelStyle = .rounded
        clearButton.controlSize = .large
        clearButton.font = .systemFont(ofSize: 13)
        clearButton.imageScaling = .scaleProportionallyDown
        clearButton.cell?.isBordered = true

        closeBurnerWindowButton.translatesAutoresizingMaskIntoConstraints = false
        closeBurnerWindowButton.setContentHuggingPriority(.defaultHigh, for: .vertical)
        closeBurnerWindowButton.isHidden = true
        closeBurnerWindowButton.alignment = .center
        closeBurnerWindowButton.bezelStyle = .rounded
        closeBurnerWindowButton.controlSize = .large
        closeBurnerWindowButton.font = .systemFont(ofSize: 13)
        closeBurnerWindowButton.imageScaling = .scaleProportionallyDown
        closeBurnerWindowButton.cell?.isBordered = true

        viewMainButtonsWrapperView.translatesAutoresizingMaskIntoConstraints = false
        viewMainButtonsWrapperView.addSubview(separator)
        viewMainButtonsWrapperView.addSubview(closeBurnerWindowButton)
        viewMainButtonsWrapperView.addSubview(clearButton)
        viewMainButtonsWrapperView.addSubview(cancelButton)

        // MARK: Container View

        view = ColorView(frame: NSRect(x: 0, y: 0, width: 344, height: 388),
                         backgroundColor: .interfaceBackground)

        view.addSubview(openFireWindowContainerView)
        view.addSubview(headerWrapperView)
        view.addSubview(openWrapperView)
        view.addSubview(detailsWrapperView)
        view.addSubview(warningWrapperView)
        view.addSubview(viewMainButtonsWrapperView)

        setupOpenFireWindowLayout(openFireWindowContainerView: openFireWindowContainerView, iconView: iconView, fireWindowMouseOverButton: fireWindowMouseOverButton)
        setupHeaderLayout(openFireWindowContainerView: openFireWindowContainerView, fireHeaderImageView: fireHeaderImageView, headerSeparator: headerSeparator)
        setupButtonsLayout(openFireWindowContainerView: openFireWindowContainerView, separator: separator)
        setupDetailsLayout()
    }

    private func setupOpenFireWindowLayout(openFireWindowContainerView: NSView, iconView: NSImageView, fireWindowMouseOverButton: MouseOverButton) {
        NSLayoutConstraint.activate([
            openFireWindowContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 84),
            openFireWindowContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            openFireWindowContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: openFireWindowContainerView.trailingAnchor),

            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),
            iconView.leadingAnchor.constraint(equalTo: openFireWindowContainerView.leadingAnchor, constant: 24),
            iconView.topAnchor.constraint(equalTo: openFireWindowContainerView.topAnchor, constant: 26),

            openFireWindowsTitleLabel.topAnchor.constraint(equalTo: openFireWindowContainerView.topAnchor, constant: 25),
            openFireWindowsTitleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            openFireWindowContainerView.trailingAnchor.constraint(equalTo: openFireWindowsTitleLabel.trailingAnchor, constant: 20),

            fireWindowDescriptionLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            openFireWindowContainerView.bottomAnchor.constraint(greaterThanOrEqualTo: fireWindowDescriptionLabel.bottomAnchor, constant: 16),
            fireWindowDescriptionLabel.topAnchor.constraint(equalTo: openFireWindowsTitleLabel.bottomAnchor, constant: 2),
            openFireWindowContainerView.trailingAnchor.constraint(equalTo: fireWindowDescriptionLabel.trailingAnchor, constant: 20),

            fireWindowMouseOverButton.topAnchor.constraint(equalTo: openFireWindowContainerView.topAnchor, constant: 16),
            fireWindowMouseOverButton.leadingAnchor.constraint(equalTo: openFireWindowContainerView.leadingAnchor, constant: 20),
            openFireWindowContainerView.trailingAnchor.constraint(equalTo: fireWindowMouseOverButton.trailingAnchor, constant: 20),
            openFireWindowContainerView.bottomAnchor.constraint(equalTo: fireWindowMouseOverButton.bottomAnchor, constant: 8),
            fireWindowMouseOverButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
        ])
    }

    private func setupHeaderLayout(openFireWindowContainerView: NSView, fireHeaderImageView: NSImageView, headerSeparator: NSBox) {
        contentHeightConstraint = viewMainButtonsWrapperView.topAnchor.constraint(equalTo: headerWrapperView.bottomAnchor, constant: 42)

        NSLayoutConstraint.activate([
            view.trailingAnchor.constraint(equalTo: headerWrapperView.trailingAnchor),
            headerWrapperView.leadingAnchor.constraint(equalTo: view.leadingAnchor),

            headerWrapperView.topAnchor.constraint(equalTo: openFireWindowContainerView.bottomAnchor),
            optionsButton.leadingAnchor.constraint(equalTo: headerWrapperView.leadingAnchor, constant: 55),
            optionsButton.topAnchor.constraint(equalTo: closeTabsLabel.bottomAnchor, constant: 8),
            headerWrapperView.heightAnchor.constraint(equalToConstant: 202),
            infoLabel.centerXAnchor.constraint(equalTo: headerWrapperView.centerXAnchor),
            headerWrapperView.trailingAnchor.constraint(equalTo: optionsButton.trailingAnchor, constant: 54),
            fireHeaderImageView.topAnchor.constraint(equalTo: headerWrapperView.topAnchor, constant: 20),
            infoLabel.topAnchor.constraint(equalTo: optionsButton.bottomAnchor, constant: 8),
            closeTabsLabel.topAnchor.constraint(equalTo: fireHeaderImageView.bottomAnchor, constant: 15),
            headerWrapperView.trailingAnchor.constraint(equalTo: headerSeparator.trailingAnchor, constant: 20),
            headerWrapperView.trailingAnchor.constraint(equalTo: infoLabel.trailingAnchor, constant: 20),
            fireHeaderImageView.centerXAnchor.constraint(equalTo: headerWrapperView.centerXAnchor),
            headerSeparator.leadingAnchor.constraint(equalTo: headerWrapperView.leadingAnchor, constant: 20),
            headerSeparator.topAnchor.constraint(equalTo: headerWrapperView.topAnchor),
            infoLabel.leadingAnchor.constraint(equalTo: headerWrapperView.leadingAnchor, constant: 20),
            closeTabsLabel.centerXAnchor.constraint(equalTo: headerWrapperView.centerXAnchor),

            infoLabel.widthAnchor.constraint(equalToConstant: 304),
            infoLabel.heightAnchor.constraint(equalToConstant: 32),

            optionsButton.heightAnchor.constraint(equalToConstant: 30),

            fireHeaderImageView.widthAnchor.constraint(equalToConstant: 128),
            fireHeaderImageView.heightAnchor.constraint(equalToConstant: 64),

            contentHeightConstraint,
        ])
    }

    private func setupButtonsLayout(openFireWindowContainerView: NSView, separator: NSBox) {
        mainButtonsToBurnerWindowContraint = viewMainButtonsWrapperView.topAnchor.constraint(equalTo: openFireWindowContainerView.bottomAnchor).priority(250)

        NSLayoutConstraint.activate([
            view.trailingAnchor.constraint(equalTo: viewMainButtonsWrapperView.trailingAnchor),
            viewMainButtonsWrapperView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.bottomAnchor.constraint(equalTo: viewMainButtonsWrapperView.bottomAnchor),

            closeBurnerWindowButton.leadingAnchor.constraint(equalTo: viewMainButtonsWrapperView.leadingAnchor, constant: 20),
            cancelButton.leadingAnchor.constraint(equalTo: viewMainButtonsWrapperView.leadingAnchor, constant: 20),
            viewMainButtonsWrapperView.trailingAnchor.constraint(equalTo: closeBurnerWindowButton.trailingAnchor, constant: 20),
            separator.topAnchor.constraint(equalTo: viewMainButtonsWrapperView.topAnchor),
            cancelButton.centerYAnchor.constraint(equalTo: viewMainButtonsWrapperView.centerYAnchor),
            viewMainButtonsWrapperView.trailingAnchor.constraint(equalTo: separator.trailingAnchor),
            clearButton.centerYAnchor.constraint(equalTo: viewMainButtonsWrapperView.centerYAnchor),
            clearButton.widthAnchor.constraint(equalTo: cancelButton.widthAnchor),
            viewMainButtonsWrapperView.trailingAnchor.constraint(equalTo: clearButton.trailingAnchor, constant: 20),
            viewMainButtonsWrapperView.bottomAnchor.constraint(equalTo: closeBurnerWindowButton.bottomAnchor, constant: 16),
            clearButton.leadingAnchor.constraint(equalTo: cancelButton.trailingAnchor, constant: 8),
            separator.leadingAnchor.constraint(equalTo: viewMainButtonsWrapperView.leadingAnchor),
            viewMainButtonsWrapperView.heightAnchor.constraint(equalToConstant: 60),

            mainButtonsToBurnerWindowContraint,
        ])
    }

    private func setupDetailsLayout() {
        optionsButtonWidthConstraint = optionsButton.widthAnchor.constraint(equalToConstant: 235).priority(250)
        detailsWrapperViewHeightContraint = detailsWrapperView.heightAnchor.constraint(equalToConstant: 263)
        collectionViewBottomConstraint = detailsWrapperView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)

        NSLayoutConstraint.activate([
            openWrapperView.topAnchor.constraint(equalTo: headerWrapperView.bottomAnchor),
            detailsWrapperView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: detailsWrapperView.trailingAnchor),
            detailsWrapperView.topAnchor.constraint(equalTo: headerWrapperView.bottomAnchor),
            view.trailingAnchor.constraint(equalTo: openWrapperView.trailingAnchor),
            openWrapperView.leadingAnchor.constraint(equalTo: view.leadingAnchor),

            warningWrapperView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            viewMainButtonsWrapperView.topAnchor.constraint(equalTo: warningWrapperView.bottomAnchor),
            view.trailingAnchor.constraint(equalTo: warningWrapperView.trailingAnchor),
            warningWrapperView.heightAnchor.constraint(equalToConstant: 32),

            closeWrapperView.leadingAnchor.constraint(equalTo: detailsWrapperView.leadingAnchor),
            scrollView.topAnchor.constraint(equalTo: closeWrapperView.bottomAnchor),
            closeWrapperView.topAnchor.constraint(equalTo: detailsWrapperView.topAnchor),
            detailsWrapperView.trailingAnchor.constraint(equalTo: closeWrapperView.trailingAnchor),
            detailsWrapperView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            scrollView.leadingAnchor.constraint(equalTo: detailsWrapperView.leadingAnchor),

            closeDetailsButton.topAnchor.constraint(equalTo: closeWrapperView.topAnchor),
            closeWrapperView.bottomAnchor.constraint(equalTo: closeDetailsButton.bottomAnchor),
            closeDetailsButton.leadingAnchor.constraint(equalTo: closeWrapperView.leadingAnchor),
            closeWrapperView.trailingAnchor.constraint(equalTo: closeDetailsButton.trailingAnchor),
            closeWrapperView.heightAnchor.constraint(equalToConstant: 42),

            openWrapperView.bottomAnchor.constraint(equalTo: openDetailsButton.bottomAnchor),
            openWrapperView.heightAnchor.constraint(equalToConstant: 42),
            openWrapperView.trailingAnchor.constraint(equalTo: openDetailsButtonImageView.trailingAnchor),
            openDetailsButton.leadingAnchor.constraint(equalTo: openWrapperView.leadingAnchor),
            openWrapperView.trailingAnchor.constraint(equalTo: openDetailsButton.trailingAnchor),
            openDetailsButtonImageView.centerYAnchor.constraint(equalTo: openWrapperView.centerYAnchor),
            openDetailsButton.topAnchor.constraint(equalTo: openWrapperView.topAnchor),

            openDetailsButton.heightAnchor.constraint(equalToConstant: 42),

            openDetailsButtonImageView.heightAnchor.constraint(equalToConstant: 16),
            openDetailsButtonImageView.widthAnchor.constraint(equalToConstant: 38),

            collectionViewBottomConstraint,
            detailsWrapperViewHeightContraint,
            optionsButtonWidthConstraint,
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.register(FirePopoverCollectionViewItem.self, forItemWithIdentifier: FirePopoverCollectionViewItem.identifier)
        collectionView.register(FirePopoverCollectionViewHeader.self, forSupplementaryViewOfKind: NSCollectionView.elementKindSectionHeader, withIdentifier: FirePopoverCollectionViewHeader.identifier)
        collectionView.delegate = self
        collectionView.dataSource = self

        if firePopoverViewModel.tabCollectionViewModel?.isBurner ?? false {
            adjustViewForBurnerWindow()
            return
        }

        updateClearButtonAppearance()
        closeDetailsButton.isHidden = true
        setupOptionsButton()
        setupOpenCloseDetailsButton()
        updateWarningWrapperView()

        subscribeToViewModel()
        subscribeToSelected()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        collectionView.nextKeyView = cancelButton

    }

    override func viewWillAppear() {
        super.viewWillAppear()

        firePopoverViewModel.refreshItems()
    }

    @objc func optionsButtonAction(_ sender: NSPopUpButton) {
        guard let tag = sender.selectedItem?.tag, let clearingOption = FirePopoverViewModel.ClearingOption(rawValue: tag) else {
            assertionFailure("Clearing option for not found for the selected menu item")
            return
        }
        firePopoverViewModel.clearingOption = clearingOption
        updateWarningWrapperView()
    }

    @objc func openNewBurnerWindowAction(_ sender: Any) {
        NSApp.delegateTyped.newBurnerWindow(self)
    }

    @objc func openDetailsButtonAction(_ sender: NSButton) {
        let isButtonFirstResponder = sender.isFirstResponder
        toggleDetails()
        if isButtonFirstResponder {
            closeDetailsButton.makeMeFirstResponder()
        }
    }

    @objc func closeDetailsButtonAction(_ sender: NSButton) {
        let isButtonFirstResponder = sender.isFirstResponder
        toggleDetails()
        collectionView.selectionIndexPaths = []
        if isButtonFirstResponder {
            openDetailsButton.makeMeFirstResponder()
        }
    }

    @objc func closeBurnerWindowButtonAction(_ sender: Any) {
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

    @objc func clearButtonAction(_ sender: Any) {
        delegate?.firePopoverViewControllerDidClear(self)
        firePopoverViewModel.burn()
    }

    @objc func cancelButtonAction(_ sender: Any) {
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
        closeDetailsButton.isHidden = !showDetails
        detailsWrapperView.isHidden = !showDetails

        updateWarningWrapperView()
        adjustContentHeight()
    }

    private func adjustContentHeight() {
        // TODO: bug! when expanding and then selecting "current tab" with no history – layout breaks
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
            os_log("FirePopoverViewController: Menu and/or font not present for optionsMenu", type: .error)
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

    private func modelItem(at indexPath: IndexPath) -> FirePopoverViewModel.Item {
        let isSelectableSection = indexPath.section == firePopoverViewModel.selectableSectionIndex
        let sectionList = isSelectableSection ? firePopoverViewModel.selectable : firePopoverViewModel.fireproofed
        return sectionList[indexPath.item]
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: FirePopoverCollectionViewItem.identifier, for: indexPath)
        guard let firePopoverItem = item as? FirePopoverCollectionViewItem else { return item }

        firePopoverItem.delegate = self
        let listItem = self.modelItem(at: indexPath)
        firePopoverItem.setItem(listItem, isFireproofed: indexPath.section == firePopoverViewModel.fireproofedSectionIndex)
        return firePopoverItem
    }

    func collectionView(_ collectionView: NSCollectionView,
                        viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind,
                        at indexPath: IndexPath) -> NSView {
        // swiftlint:disable:next force_cast
        let view = collectionView.makeSupplementaryView(ofKind: NSCollectionView.elementKindSectionHeader, withIdentifier: FirePopoverCollectionViewHeader.identifier, for: indexPath) as! FirePopoverCollectionViewHeader

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
#if DEBUG
final class HistoryTabExtensionMock: TabExtension, HistoryExtensionProtocol {

    var historyEntries: [HistoryEntry] {
        [
            .init(identifier: UUID(), url: .duckDuckGo, failedToLoad: false, numberOfTotalVisits: 1, lastVisit: .init(), visits: [], numberOfTrackersBlocked: 0, blockedTrackingEntities: [], trackersFound: false),
            .init(identifier: UUID(), url: URL(string: "http://anothersearch.com")!, failedToLoad: false, numberOfTotalVisits: 1, lastVisit: .init(), visits: [], numberOfTrackersBlocked: 0, blockedTrackingEntities: [], trackersFound: false),
            .init(identifier: UUID(), url: URL(string: "http://bit.li")!, failedToLoad: false, numberOfTotalVisits: 1, lastVisit: .init(), visits: [], numberOfTrackersBlocked: 0, blockedTrackingEntities: [], trackersFound: false),
        ]
    }
    var localHistory: [Visit] {
        historyEntries.map { Visit(date: .init(), identifier: nil, historyEntry: $0) }
    }
    func getPublicProtocol() -> HistoryExtensionProtocol { self }

}

@available(macOS 14.0, *)
#Preview("With History", traits: .fixedLayout(width: 344, height: 650)) { {
    let historyExtensionMock = HistoryTabExtensionMock()
    let extensionBuilder = TestTabExtensionsBuilder(load: [HistoryTabExtensionMock.self]) { builder in { _, _ in
        builder.override {
            historyExtensionMock
        }
    }}

    let tab = Tab(content: .newtab, extensionsBuilder: extensionBuilder)
    let tabCollection = TabCollection(tabs: [tab])
    let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)

    let vc = FirePopoverViewController(fireViewModel: FireViewModel(), tabCollectionViewModel: tabCollectionViewModel)
    vc.onDeinit {
        withExtendedLifetime(tabCollectionViewModel) {}
    }

    return vc._preview_hidingWindowControlsOnAppear()

}() }
// TODO: adjust
@available(macOS 14.0, *)
#Preview("Empty", traits: .fixedLayout(width: 344, height: 650)) { {
    let historyExtensionMock = HistoryTabExtensionMock()
    let extensionBuilder = TestTabExtensionsBuilder(load: [HistoryTabExtensionMock.self]) { builder in { _, _ in
        builder.override {
            historyExtensionMock
        }
    }}

    let tab = Tab(content: .newtab, extensionsBuilder: extensionBuilder)
    let tabCollection = TabCollection(tabs: [tab])
    let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)

    let vc = FirePopoverViewController(fireViewModel: FireViewModel(), tabCollectionViewModel: tabCollectionViewModel)
    vc.onDeinit {
        withExtendedLifetime(tabCollectionViewModel) {}
    }

    return vc._preview_hidingWindowControlsOnAppear()

}() }

@available(macOS 14.0, *)
#Preview("Burner", traits: .fixedLayout(width: 344, height: 650)) { {
    let historyExtensionMock = HistoryTabExtensionMock()
    let extensionBuilder = TestTabExtensionsBuilder(load: [HistoryTabExtensionMock.self]) { builder in { _, _ in
        builder.override {
            historyExtensionMock
        }
    }}

    let tab = Tab(content: .newtab, extensionsBuilder: extensionBuilder)
    let tabCollection = TabCollection(tabs: [tab])
    let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)

    let vc = FirePopoverViewController(fireViewModel: FireViewModel(), tabCollectionViewModel: tabCollectionViewModel)
    vc.onDeinit {
        withExtendedLifetime(tabCollectionViewModel) {}
    }

    return vc._preview_hidingWindowControlsOnAppear()

}() }
#endif
