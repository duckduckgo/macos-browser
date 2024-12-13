//
//  DownloadsViewController.swift
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
import SwiftUI

protocol DownloadsViewControllerDelegate: AnyObject {
    func clearDownloadsActionTriggered()
}

final class DownloadsViewController: NSViewController {

    static let preferredContentSize = CGSize(width: 420, height: 500)

    private lazy var titleLabel = NSTextField(string: UserText.downloadsDialogTitle)

    private lazy var openDownloadsFolderButton = MouseOverButton(image: .openDownloadsFolder, target: self, action: #selector(openDownloadsFolderAction))
    private lazy var clearDownloadsButton = MouseOverButton(image: .clearDownloads, target: self, action: #selector(clearDownloadsAction))

    private lazy var scrollView = NSScrollView()
    private lazy var tableView = NSTableView()
    private var hostingViewConstraints: [NSLayoutConstraint] = []
    private var tableViewHeightConstraint: NSLayoutConstraint!
    private var errorBannerTopAnchorConstraint: NSLayoutConstraint!
    private var cellIndexToUnselect: Int?

    weak var delegate: DownloadsViewControllerDelegate?

    private let separator = NSBox()
    private let viewModel: DownloadListViewModel
    private var downloadsCancellable: AnyCancellable?
    private var errorBannerCancellable: AnyCancellable?
    private var errorBannerHostingView: NSHostingView<DownloadsErrorBannerView>?

    init(viewModel: DownloadListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    override func loadView() {
        view = NSView()

        view.addSubview(titleLabel)
        view.addSubview(openDownloadsFolderButton)
        view.addSubview(clearDownloadsButton)
        view.addSubview(scrollView)

        titleLabel.isSelectable = false
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
        titleLabel.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.drawsBackground = false
        titleLabel.font = .preferredFont(forTextStyle: .title3)
        titleLabel.textColor = .labelColor

        openDownloadsFolderButton.translatesAutoresizingMaskIntoConstraints = false
        openDownloadsFolderButton.alignment = .center
        openDownloadsFolderButton.bezelStyle = .shadowlessSquare
        openDownloadsFolderButton.isBordered = false
        openDownloadsFolderButton.imagePosition = .imageOnly
        openDownloadsFolderButton.imageScaling = .scaleProportionallyDown
        openDownloadsFolderButton.toolTip = UserText.openDownloadsFolderTooltip
        openDownloadsFolderButton.cornerRadius = 4
        openDownloadsFolderButton.backgroundInset = CGPoint(x: 2, y: 2)
        openDownloadsFolderButton.normalTintColor = .button
        openDownloadsFolderButton.mouseDownColor = .buttonMouseDown
        openDownloadsFolderButton.mouseOverColor = .buttonMouseOver

        clearDownloadsButton.translatesAutoresizingMaskIntoConstraints = false
        clearDownloadsButton.alignment = .center
        clearDownloadsButton.bezelStyle = .shadowlessSquare
        clearDownloadsButton.isBordered = false
        clearDownloadsButton.imagePosition = .imageOnly
        clearDownloadsButton.imageScaling = .scaleProportionallyDown
        clearDownloadsButton.toolTip = UserText.clearDownloadHistoryTooltip
        clearDownloadsButton.setAccessibilityIdentifier("DownloadsViewController.clearDownloadsButton")
        clearDownloadsButton.cornerRadius = 4
        clearDownloadsButton.backgroundInset = CGPoint(x: 2, y: 2)
        clearDownloadsButton.normalTintColor = .button
        clearDownloadsButton.mouseDownColor = .buttonMouseDown
        clearDownloadsButton.mouseOverColor = .buttonMouseOver

        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.usesPredominantAxisScrolling = false
        scrollView.automaticallyAdjustsContentInsets = false

        let clipView = NSClipView()
        clipView.documentView = tableView

        clipView.autoresizingMask = [.width, .height]
        clipView.drawsBackground = false
        clipView.frame = CGRect(x: 0, y: 0, width: 420, height: 440)

        tableView.addTableColumn(NSTableColumn())

        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.gridColor = .clear
        tableView.style = .fullWidth
        tableView.rowHeight = 60
        tableView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        tableView.allowsMultipleSelection = false
        tableView.doubleAction = #selector(DownloadsViewController.doubleClickAction)
        tableView.target = self
        tableView.delegate = self
        tableView.dataSource = self
        tableView.menu = setUpContextMenu()

        scrollView.contentView = clipView

        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(separator)

        let swiftUIView = DownloadsErrorBannerView(dismiss: { self.dismiss() },
                                                   errorType: NSApp.isSandboxed ? .openHelpURL : .openSystemSettings)
        let hostingView = NSHostingView(rootView: swiftUIView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.isHidden = true
        view.addSubview(hostingView)
        errorBannerHostingView = hostingView

        setupLayout(separator: separator, hostingView: hostingView)
    }

    private func setupLayout(separator: NSBox, hostingView: NSHostingView<DownloadsErrorBannerView>) {
        tableViewHeightConstraint = scrollView.heightAnchor.constraint(equalToConstant: 440)
        errorBannerTopAnchorConstraint = scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 12)

        hostingViewConstraints = [
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            hostingView.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 12),
            scrollView.topAnchor.constraint(equalTo: hostingView.bottomAnchor, constant: 12)
        ]

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),

            openDownloadsFolderButton.widthAnchor.constraint(equalToConstant: 32),
            openDownloadsFolderButton.heightAnchor.constraint(equalToConstant: 32),
            openDownloadsFolderButton.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8),
            openDownloadsFolderButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            clearDownloadsButton.widthAnchor.constraint(equalToConstant: 32),
            clearDownloadsButton.heightAnchor.constraint(equalToConstant: 32),
            clearDownloadsButton.leadingAnchor.constraint(equalTo: openDownloadsFolderButton.trailingAnchor),
            view.trailingAnchor.constraint(equalTo: clearDownloadsButton.trailingAnchor, constant: 11),
            clearDownloadsButton.centerYAnchor.constraint(equalTo: openDownloadsFolderButton.centerYAnchor),

            separator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            separator.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -2),
            separator.topAnchor.constraint(equalTo: view.topAnchor, constant: 43),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 12),

            errorBannerTopAnchorConstraint,
            tableViewHeightConstraint
        ])
    }

    private func showErrorBanner() {
        errorBannerHostingView?.isHidden = false
        NSLayoutConstraint.deactivate([errorBannerTopAnchorConstraint])
        NSLayoutConstraint.activate(hostingViewConstraints)
        view.layoutSubtreeIfNeeded()
    }

    private func hideErrorBanner() {
        errorBannerHostingView?.isHidden = true
        NSLayoutConstraint.deactivate(hostingViewConstraints)
        NSLayoutConstraint.activate([errorBannerTopAnchorConstraint])
        view.layoutSubtreeIfNeeded()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        preferredContentSize = Self.preferredContentSize
        setupDragAndDrop()
    }

    override func viewWillAppear() {

        downloadsCancellable = viewModel.$items
            .throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
            .scan((old: [DownloadViewModel](), new: viewModel.items), { ($0.new, $1) })
            .sink { [weak self] value in
                guard let self = self else { return }
                let diff = value.new.difference(from: value.old) { $0.id == $1.id }
                guard !diff.isEmpty else { return }

                self.tableView.beginUpdates()
                for change in diff {
                    switch change {
                    case .insert(offset: let offset, element: _, associatedWith: _):
                        self.tableView.insertRows(at: IndexSet(integer: offset), withAnimation: .slideDown)
                    case .remove(offset: let offset, element: _, associatedWith: _):
                        self.tableView.removeRows(at: IndexSet(integer: offset), withAnimation: .slideUp)
                    }
                }
                self.tableView.reloadData(forRowIndexes: IndexSet(integer: value.new.count), columnIndexes: IndexSet(integer: 0))
                self.tableView.endUpdates()
                self.updateHeight()

                // at this point all visible cells have started their progress animation
                for change in diff {
                    if case .insert(_, element: let item, _) = change {
                        item.didAppear() // yet invisible cells shouldn‘t animate their progress when scrolled to
                    }
                }
            }

        errorBannerCancellable = viewModel.$shouldShowErrorBanner
            .sink { [weak self] shouldShowErrorBanner in
                guard let self = self else { return }

                if shouldShowErrorBanner {
                    self.showErrorBanner()
                } else {
                    self.hideErrorBanner()
                }
            }

        for item in viewModel.items {
            item.didAppear() // initial table appearance should have no progress animations
        }
        tableView.reloadData()
        updateHeight()
    }

    override func viewWillDisappear() {
        downloadsCancellable = nil
        errorBannerCancellable = nil
    }

    private func setUpContextMenu() -> NSMenu {
        let menu = NSMenu {
            NSMenuItem(title: UserText.downloadsOpenItem, action: #selector(openDownloadAction), target: self)
            NSMenuItem(title: UserText.downloadsShowInFinderItem, action: #selector(revealDownloadAction), target: self)
            NSMenuItem.separator()
            NSMenuItem(title: UserText.downloadsCopyLinkItem, action: #selector(copyDownloadLinkAction), target: self)
            NSMenuItem(title: UserText.downloadsOpenWebsiteItem, action: #selector(openOriginatingWebsiteAction), target: self)
            NSMenuItem.separator()
            NSMenuItem(title: UserText.downloadsRemoveFromListItem, action: #selector(removeDownloadAction), target: self)
            NSMenuItem(title: UserText.downloadsStopItem, action: #selector(cancelDownloadAction), target: self)
            NSMenuItem(title: UserText.downloadsRestartItem, action: #selector(restartDownloadAction), target: self)
            NSMenuItem(title: UserText.downloadsClearAllItem, action: #selector(clearDownloadsAction), target: self)
        }
        menu.delegate = self
        return menu
    }

    private func index(for sender: Any) -> Int? {
        let row: Int
        switch sender {
        case let button as NSButton:
            let converted = tableView.convert(button.bounds.origin, from: button)
            row = tableView.row(at: converted)
        case is NSMenuItem, is NSMenu, is NSTableView:
            row = tableView.clickedRow
        default:
            assertionFailure("Unexpected sender")
            return nil
        }
        guard viewModel.items.indices.contains(row) else { return nil }
        return row
    }

    static private let maxNumberOfRows: CGFloat = 7.3
    private func updateHeight() {
        var tableViewHeight: CGFloat = min(Self.maxNumberOfRows, CGFloat(tableView.numberOfRows)) * tableView.rowHeight
        if let scrollView = tableView.enclosingScrollView {
            tableViewHeight += scrollView.contentInsets.top + scrollView.contentInsets.bottom
        }

        tableViewHeightConstraint?.constant = tableViewHeight
    }

    // MARK: User Actions

    @objc func openDownloadsFolderAction(_ sender: Any) {
        let prefs = DownloadsPreferences.shared
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        var url: URL?
        var itemToSelect: URL?

        if prefs.alwaysRequestDownloadLocation {
            url = prefs.lastUsedCustomDownloadLocation

            // reveal the last completed download
            if let lastDownloaded = viewModel.items.first/* last added */(where: {
                // should still exist
                if let url = $0.localURL, FileManager.default.fileExists(atPath: url.path) { true } else { false }
            }),
               let lastDownloadedURL = lastDownloaded.localURL,
               !viewModel.items.contains(where: { $0.localURL?.deletingLastPathComponent().path == url?.path  }) || url == nil {

                url = lastDownloadedURL.deletingLastPathComponent()
                // select last downloaded item
                itemToSelect = lastDownloadedURL

            } /* else fallback to the last location chosen in the Save Panel */

        } else {
            // open preferred downlod location
            url = prefs.effectiveDownloadLocation
        }

        let folder = url ?? downloads

        _=NSWorkspace.shared.selectFile(itemToSelect?.path, inFileViewerRootedAtPath: folder.path)
        // hack for the sandboxed environment:
        // when we have no permission to open a folder we don‘t have access to
        // try to guess a file that would most probably exist and reveal it: it‘s the ".DS_Store" file
        || NSWorkspace.shared.selectFile(folder.appendingPathComponent(".DS_Store").path, inFileViewerRootedAtPath: folder.path)
        // fallback to default Downloads folder
        || NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: downloads.path)

        self.dismiss()
    }

    @objc func clearDownloadsAction(_ sender: Any) {
        viewModel.cleanupInactiveDownloads()
        self.dismiss()
        delegate?.clearDownloadsActionTriggered()
    }

    @objc func cancelDownloadAction(_ sender: Any) {
        guard let index = index(for: sender) else { return }
        viewModel.cancelDownload(at: index)
    }

    @objc func removeDownloadAction(_ sender: Any) {
        guard let index = index(for: sender) else { return }
        viewModel.removeDownload(at: index)
    }

    @objc func revealDownloadAction(_ sender: Any) {
        guard let index = index(for: sender),
              let url = viewModel.items[safe: index]?.localURL
        else { return }
        self.dismiss()
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc func openDownloadAction(_ sender: Any) {
        guard let index = index(for: sender),
              let url = viewModel.items[safe: index]?.localURL
        else { return }
        self.dismiss()
        NSWorkspace.shared.open(url)
    }

    @objc func restartDownloadAction(_ sender: Any) {
        guard let index = index(for: sender) else { return }
        viewModel.restartDownload(at: index)
    }

    @objc func copyDownloadLinkAction(_ sender: Any) {
        guard let index = index(for: sender),
              let url = viewModel.items[safe: index]?.url
        else { return }

        NSPasteboard.general.copy(url)
    }

    @objc func openOriginatingWebsiteAction(_ sender: Any) {
        guard let index = index(for: sender),
              let url = viewModel.items[safe: index]?.websiteURL
        else { return }

        self.dismiss()
        WindowControllersManager.shared.show(url: url, source: .historyEntry, newTab: true)
    }

    @objc func doubleClickAction(_ sender: Any) {
        if index(for: sender) != nil {
            openDownloadAction(sender)
        } else {
            openDownloadsFolderAction(sender)
        }
    }

    private func setupDragAndDrop() {
        tableView.registerForDraggedTypes([.fileURL])
        tableView.setDraggingSourceOperationMask(NSDragOperation.none, forLocal: true)
        tableView.setDraggingSourceOperationMask(NSDragOperation.move, forLocal: false)
    }

}

extension DownloadsViewController: NSMenuDelegate {

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let index = index(for: menu),
              let item = viewModel.items[safe: index]
        else {
            menu.cancelTracking()
            return
        }

        for menuItem in menu.items {
            switch menuItem.action {
            case #selector(openDownloadAction(_:)),
                #selector(revealDownloadAction(_:)):
                if case .complete(.some(let url)) = item.state,
                   FileManager.default.fileExists(atPath: url.path) {
                    menuItem.isHidden = false
                } else {
                    menuItem.isHidden = true
                }

            case #selector(copyDownloadLinkAction(_:)):
                menuItem.isHidden = false
            case #selector(openOriginatingWebsiteAction(_:)):
                menuItem.isHidden = !(item.websiteURL != nil)

            case #selector(cancelDownloadAction(_:)):
                menuItem.isHidden = !(item.state.progress != nil)
            case #selector(removeDownloadAction(_:)):
                menuItem.isHidden = !(item.state.progress == nil)
            case #selector(restartDownloadAction(_:)):
                menuItem.isHidden = !(item.state.error != nil)

            case #selector(clearDownloadsAction(_:)):
                continue
            default:
                continue
            }
        }
    }
}

extension DownloadsViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return downloadsCancellable == nil ? 0 : viewModel.items.count + 1 // updated on viewDidAppear
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return viewModel.items[safe: row]
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if viewModel.items.isEmpty {
            return tableView.makeView(withIdentifier: .init(NoDownloadsCellView.className()), owner: self) as? NoDownloadsCellView
            ?? NoDownloadsCellView(identifier: .init(NoDownloadsCellView.className()))

        } else if viewModel.items.indices.contains(row) {
            return tableView.makeView(withIdentifier: .init(DownloadsCellView.className()), owner: self) as? DownloadsCellView
            ?? DownloadsCellView(identifier: .init(DownloadsCellView.className()))
        } else {
            return tableView.makeView(withIdentifier: .init(OpenDownloadsCellView.className()), owner: self) as? OpenDownloadsCellView
            ?? OpenDownloadsCellView(identifier: .init(OpenDownloadsCellView.className()))
        }
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if viewModel.items.indices.contains(row) {
            return true
        } else {
            return false
        }
    }

    func tableViewSelectionIsChanging(_ notification: Notification) {
        func changeCellSelection(in row: Int?, selected: Bool) {
            guard let row = row else { return }

            if let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) {
                for subview in rowView.subviews where subview is DownloadsCellView {
                    (subview as? DownloadsCellView)?.isSelected = selected
                }
            }
        }

        changeCellSelection(in: cellIndexToUnselect, selected: false)
        if tableView.selectedRowIndexes.count > 0 {
            changeCellSelection(in: tableView.selectedRow, selected: true)
            cellIndexToUnselect = tableView.selectedRow
        }
    }

    // MARK: - Drag & Drop
    // Draging from the table view and dropping to Desktop or Finder

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = viewModel.items[safe: row]
        guard let url = item?.localURL?.absoluteURL else { return nil }

        return url as NSPasteboardWriting
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        return false
    }

}

enum DownloadsErrorViewType {
    case openHelpURL
    case openSystemSettings

    var errorMessage: String {
        return UserText.downloadsErrorMessage
    }

    var title: String {
        switch self {
        case .openHelpURL: return UserText.downloadsErrorSandboxCallToAction
        case .openSystemSettings: return UserText.downloadsErrorNonSandboxCallToAction
        }
    }

    @MainActor func onAction() {
        switch self {
        case .openHelpURL:
            let updateHelpURL = URL(string: "https://support.apple.com/guide/mac-help/get-macos-updates-and-apps-mh35618/mac")!
            WindowControllersManager.shared.show(url: updateHelpURL, source: .ui, newTab: true)
        case .openSystemSettings:
            let softwareUpdateURL = URL(string: "x-apple.systempreferences:com.apple.Software-Update-Settings.extension")!
            NSWorkspace.shared.open(softwareUpdateURL)
        }
    }
}

struct DownloadsErrorBannerView: View {
    var dismiss: () -> Void
    let errorType: DownloadsErrorViewType

    var body: some View {
        HStack {
            Image("Clear-Recolorable-16")
            Text(errorType.errorMessage)
                .font(.body)
            Button(errorType.title) {
                errorType.onAction()
                dismiss()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .frame(width: 420)
        .frame(minHeight: 84.0)
    }
}

#if DEBUG
@available(macOS 14.0, *)
#Preview(traits: DownloadsViewController.preferredContentSize.fixedLayout) { {

    let store = DownloadListStoreMock()
    store.fetchBlock = { completion in
        completion(.success(previewDownloadListItems))
    }
    let viewModel = DownloadListViewModel(fireWindowSession: nil, coordinator: DownloadListCoordinator(store: store))
    return DownloadsViewController(viewModel: viewModel)
}() }
#endif
