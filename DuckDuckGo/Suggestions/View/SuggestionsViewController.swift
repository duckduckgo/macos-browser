//
//  SearchSuggestionsViewController.swift
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
import os.log

protocol SuggestionsViewControllerDelegate: AnyObject {

    func suggestionsViewControllerDidConfirmSelection(_ suggestionsViewController: SuggestionsViewController)

}

class SuggestionsViewController: NSViewController {

    weak var delegate: SuggestionsViewControllerDelegate?

    @IBOutlet weak var tableView: NSTableView!

    let suggestionsViewModel: SuggestionsViewModel

    required init?(coder: NSCoder) {
        fatalError("SuggestionsViewController: Bad initializer")
    }

    required init?(coder: NSCoder, suggestionsViewModel: SuggestionsViewModel) {
        self.suggestionsViewModel = suggestionsViewModel

        super.init(coder: coder)
    }

    var suggestionsCancelable: AnyCancellable?
    var selectionIndexCancelable: AnyCancellable?

    var mouseUpEventsMonitor: Any?
    var mouseDownEventsMonitor: Any?

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self

        addTrackingArea()
        bindSuggestions()
        bindSelectionIndex()
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        addMouseEventsMonitors()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        removeMouseEventsMonitor()
        clearSelection()
    }

    private func addTrackingArea() {
        let trackingOptions: NSTrackingArea.Options = [.activeInActiveApp, .mouseEnteredAndExited, .enabledDuringMouseDrag, .mouseMoved]
        let trackingArea = NSTrackingArea(rect: tableView.frame, options: trackingOptions, owner: self, userInfo: nil)
        tableView.addTrackingArea(trackingArea)
    }

    private func addMouseEventsMonitors() {
        let upEventTypes: NSEvent.EventTypeMask = [.leftMouseUp, .rightMouseUp]
        mouseUpEventsMonitor = NSEvent.addLocalMonitorForEvents(matching: upEventTypes, handler: mouseUp)

        let downEventTypes: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]
        mouseDownEventsMonitor = NSEvent.addLocalMonitorForEvents(matching: downEventTypes, handler: mouseDown)
    }

    private func removeMouseEventsMonitor() {
        if let monitor = mouseUpEventsMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func bindSuggestions() {
        suggestionsCancelable = suggestionsViewModel.suggestions.$items.sinkAsync { _ in
            self.displayNewSuggestions()
        }
    }

    private func bindSelectionIndex() {
        selectionIndexCancelable = suggestionsViewModel.suggestions.$selectionIndex.sinkAsync { _ in
            self.selectRow(at: self.suggestionsViewModel.suggestions.selectionIndex)
        }
    }

    private func displayNewSuggestions() {
        if suggestionsViewModel.suggestions.items.isEmpty {
            closeWindow()
        } else {
            tableView.reloadData()
        }
    }

    private func selectRow(at index: Int?) {
        guard let index = index,
              index >= 0,
              !suggestionsViewModel.suggestions.items.isEmpty,
              suggestionsViewModel.suggestions.items.count > index else {
            clearSelection()
            return
        }

        tableView.selectRowIndexes(IndexSet(arrayLiteral: index), byExtendingSelection: false)
    }

    private func selectRow(at point: NSPoint) {
        let flippedPoint = view.convert(point, to: tableView)
        let row = tableView.row(at: flippedPoint)
        selectRow(at: row)
    }

    private func clearSelection() {
        tableView.deselectAll(self)
    }

    override func mouseEntered(with event: NSEvent) {
        selectRow(at: event.locationInWindow)
    }

    override func mouseMoved(with event: NSEvent) {
        selectRow(at: event.locationInWindow)
    }

    override func mouseExited(with event: NSEvent) {
        clearSelection()
    }

    func mouseDown(with event: NSEvent) -> NSEvent? {
        if event.window == view.window {
            return nil
        }

        closeWindow()
        return event
    }

    func mouseUp(with event: NSEvent) -> NSEvent? {
        if event.window == view.window {
            closeWindow()
            delegate?.suggestionsViewControllerDidConfirmSelection(self)
            return nil
        }
        return event
    }

    private func closeWindow() {
        guard let window = view.window else {
            os_log("SuggestionsViewController: Window not available", log: OSLog.Category.general, type: .error)
            return
        }

        window.parent?.removeChildWindow(window)
        window.orderOut(nil)
    }

}

extension SuggestionsViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return suggestionsViewModel.suggestions.items.count
    }

}

extension SuggestionsViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let suggestionTableCellView = tableView.makeView(
                withIdentifier: NSUserInterfaceItemIdentifier(rawValue: SuggestionTableCellView.identifier), owner: self)
                as? SuggestionTableCellView else {
            os_log("SuggestionsViewController: Making of table cell view failed", log: OSLog.Category.general, type: .error)
            return nil
        }

        let suggestion = suggestionsViewModel.suggestions.items[row]
        suggestionTableCellView.display(suggestion)
        return suggestionTableCellView
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard let suggestionTableRowView = tableView.makeView(
                withIdentifier: NSUserInterfaceItemIdentifier(rawValue: SuggestionTableRowView.identifier), owner: self)
                as? SuggestionTableRowView else {
            os_log("SuggestionsViewController: Making of table row view failed", log: OSLog.Category.general, type: .error)
            return nil
        }
        return suggestionTableRowView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if tableView.selectedRow == -1 { return }

        if suggestionsViewModel.suggestions.selectionIndex != tableView.selectedRow {
            suggestionsViewModel.suggestions.select(at: tableView.selectedRow)
        }
    }

}
