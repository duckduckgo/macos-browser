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

protocol DownloadsViewControllerDelegate: AnyObject {

    func clearDownloadsActionTriggered()

}

final class DownloadsViewController: NSViewController {

    static func create() -> Self {
        let storyboard = NSStoryboard(name: "Downloads", bundle: nil)
        // swiftlint:disable force_cast
        let controller = storyboard.instantiateInitialController() as! Self
        controller.loadView()
        // swiftlint:enable force_cast
        return controller
    }

    @IBOutlet var openDownloadsFolderButton: NSButton!
    @IBOutlet var clearDownloadsButton: NSButton!

    @IBOutlet var contextMenu: NSMenu!
    @IBOutlet var tableView: NSTableView!
    @IBOutlet var tableViewHeightConstraint: NSLayoutConstraint?
    private var cellIndexToUnselect: Int?

    weak var delegate: DownloadsViewControllerDelegate?

    var viewModel = DownloadListViewModel()
    var downloadsCancellable: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupDragAndDrop()

        openDownloadsFolderButton.toolTip = UserText.openDownloadsFolderTooltip
        clearDownloadsButton.toolTip = UserText.clearDownloadHistoryTooltip
    }

    override func viewWillAppear() {
        viewModel.filterRemovedDownloads()

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
            }
        tableView.reloadData()
        updateHeight()
    }

    override func viewWillDisappear() {
        downloadsCancellable = nil
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
        tableViewHeightConstraint?.constant = min(Self.maxNumberOfRows, CGFloat(tableView.numberOfRows)) * tableView.rowHeight
            + (tableView.enclosingScrollView?.contentInsets.top ?? 0)
            + (tableView.enclosingScrollView?.contentInsets.bottom ?? 0)
    }

    // MARK: User Actions

    @IBAction func openDownloadsFolderAction(_ sender: Any) {
        guard let url = DownloadsPreferences().effectiveDownloadLocation
                ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        else {
            return
        }
        self.dismiss()
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }

    @IBAction func clearDownloadsAction(_ sender: Any) {
        viewModel.cleanupInactiveDownloads()
        self.dismiss()
        delegate?.clearDownloadsActionTriggered()
    }

    @IBAction func openDownloadedFileAction(_ sender: Any) {
        guard let index = index(for: sender),
              let url = viewModel.items[safe: index]?.localURL
        else { return }
        NSWorkspace.shared.open(url)
    }

    @IBAction func cancelDownloadAction(_ sender: Any) {
        guard let index = index(for: sender) else { return }
        viewModel.cancelDownload(at: index)
    }

    @IBAction func removeDownloadAction(_ sender: Any) {
        guard let index = index(for: sender) else { return }
        viewModel.removeDownload(at: index)
    }

    @IBAction func revealDownloadAction(_ sender: Any) {
        guard let index = index(for: sender),
              let url = viewModel.items[safe: index]?.localURL
        else { return }
        self.dismiss()
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openDownloadAction(_ sender: Any) {
        guard let index = index(for: sender),
              let url = viewModel.items[safe: index]?.localURL
        else { return }
        self.dismiss()
        NSWorkspace.shared.open(url)
    }

    @IBAction func restartDownloadAction(_ sender: Any) {
        guard let index = index(for: sender) else { return }
        viewModel.restartDownload(at: index)
    }

    @IBAction func copyDownloadLinkAction(_ sender: Any) {
        guard let index = index(for: sender),
              let url = viewModel.items[safe: index]?.url
        else { return }

        NSPasteboard.general.copy(url)
    }

    @IBAction func openOriginatingWebsiteAction(_ sender: Any) {
        guard let index = index(for: sender),
              let url = viewModel.items[safe: index]?.websiteURL
        else { return }

        self.dismiss()
        WindowControllersManager.shared.show(url: url, newTab: true)
    }

    @IBAction func doubleClickAction(_ sender: Any) {
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

    // swiftlint:disable cyclomatic_complexity
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let index = index(for: menu),
              let item = viewModel.items[safe: index]
        else {
            menu.cancelTracking()
            return
        }

        for menuItem in menu.items {
            switch menuItem.action {
            case #selector(openDownloadedFileAction(_:)),
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
    // swiftlint:enable cyclomatic_complexity

}

extension DownloadsViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return viewModel.items.count + 1
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return viewModel.items[safe: row]
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier: NSUserInterfaceItemIdentifier
        if viewModel.items.isEmpty {
            identifier = .noDownloadsCell
        } else if viewModel.items.indices.contains(row) {
            identifier = .downloadCell
        } else {
            identifier = .openDownloadsCell
        }
        let cell = tableView.makeView(withIdentifier: identifier, owner: nil)
        if identifier == .downloadCell {
            cell?.menu = contextMenu
        }
        return cell
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

private extension NSUserInterfaceItemIdentifier {
    static let downloadCell = NSUserInterfaceItemIdentifier(rawValue: "cell")
    static let noDownloadsCell = NSUserInterfaceItemIdentifier(rawValue: "NoDownloads")
    static let openDownloadsCell = NSUserInterfaceItemIdentifier(rawValue: "OpenDownloads")
}
