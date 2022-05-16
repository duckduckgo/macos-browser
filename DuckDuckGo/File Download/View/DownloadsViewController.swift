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
import Carbon.HIToolbox

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

    @IBOutlet var contextMenu: NSMenu!
    @IBOutlet var tableView: NSTableView!
    @IBOutlet var tableViewHeightConstraint: NSLayoutConstraint?
    @IBOutlet var openDownloadsButton: NSButton!
    @IBOutlet var clearButton: NSButton!

    private static let openDownloadsLinkTag = 67
    var openDownloadsLink: NSButton? {
        didSet {
            setUpKeyViewCycle()
        }
    }
    private var cellIndexToUnselect: Int?

    weak var delegate: DownloadsViewControllerDelegate?

    var viewModel = DownloadListViewModel()
    var downloadsCancellable: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupDragAndDrop()
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

    override func viewDidAppear() {
        setUpKeyViewCycle()
    }

    override func viewWillDisappear() {
        downloadsCancellable = nil
    }

    private func setUpKeyViewCycle() {
        self.clearButton.nextKeyView = self.viewModel.items.isEmpty ? self.openDownloadsLink : self.tableView
        if !self.viewModel.items.isEmpty {
            self.tableView.nextKeyView = self.openDownloadsLink
        }
        self.openDownloadsLink?.nextKeyView = self.openDownloadsButton
    }

    private func index(for sender: Any) -> Int? {
        var row: Int
        switch sender {
        case let view as NSView:
            let converted = tableView.convert(view.bounds.center, from: view)
            row = tableView.row(at: converted)
        case is NSMenuItem, is NSMenu, is NSTableView:
            row = tableView.clickedRow
            if row == -1 {
                row = tableView.selectedRow
            }
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
              let url = viewModel.items[safe: index]?.url as NSURL?
        else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.URL], owner: nil)
        url.write(to: pasteboard)
        pasteboard.setString(url.absoluteString ?? "", forType: .string)
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

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_DownArrow:
            guard !viewModel.items.isEmpty else { break }
            tableView.makeMeFirstResponder()
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            tableView.scrollRowToVisible(0)
            return

        case kVK_UpArrow:
            guard !viewModel.items.isEmpty else { break }
            tableView.makeMeFirstResponder()
            let row = tableView.numberOfRows - 1
            tableView.selectRowIndexes(IndexSet(integer: viewModel.items.count - 1), byExtendingSelection: false)
            tableView.scrollRowToVisible(row)
            return

        case kVK_Space:
            let selectedRow = tableView.selectedRow
            guard (0..<tableView.numberOfRows).contains(selectedRow),
                  let menu = tableView.view(atColumn: 0, row: selectedRow, makeIfNecessary: false)?.menu
            else {
                break
            }
            let frame = tableView.frameOfCell(atColumn: 0, row: selectedRow)
            menu.popUp(positioning: nil, at: NSPoint(x: frame.minX, y: frame.maxY), in: tableView)
            return

        case kVK_Return, kVK_ANSI_KeypadEnter:
            guard tableView.selectedRow >= 0,
                  performDefaultAction(forItemAt: tableView.selectedRow)
            else { break }

            return

        default:
            break
        }
        super.keyDown(with: event)
    }

    private func performDefaultAction(forItemAt row: Int) -> Bool {
        guard let cell = tableView.view(atColumn: 0, row: tableView.selectedRow, makeIfNecessary: false) as? DownloadsCellView else {
            return false
        }
        if !cell.cancelButton.isHidden {
            cell.cancelButton.performClick(nil)
        } else if !cell.revealButton.isHidden {
            cell.revealButton.performClick(nil)
        } else if !cell.restartButton.isHidden {
            cell.restartButton.performClick(nil)
        } else {
            return false
        }
        return true
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
        switch identifier {
        case .downloadCell:
            cell?.menu = contextMenu
        case .openDownloadsCell, .noDownloadsCell:
            self.openDownloadsLink = cell?.viewWithTag(Self.openDownloadsLinkTag) as? NSButton
        default: break
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
