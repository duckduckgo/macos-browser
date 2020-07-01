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

class SuggestionsViewController: NSViewController {

    @IBOutlet weak var tableView: NSTableView!

    var suggestionsViewModel: SuggestionsViewModel? {
        didSet {
            guard isViewLoaded else {
                //todo os_log warning
                return
            }

            bindSuggestions()
        }
    }

    var suggestionsCancelable: AnyCancellable?

    var mouseUpEventsMonitor: Any?
    var mouseDownEventsMonitor: Any?

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self

        addTrackingArea()
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
        suggestionsCancelable = suggestionsViewModel?.suggestions.$items.sinkAsync { _ in
            self.tableView.reloadData()
            self.selectRow(at: 0)
        }
    }

    private func selectRow(at index: Int) {
        guard index >= 0 else {
            return
        }

        if let suggestionsViewModel = suggestionsViewModel,
           !suggestionsViewModel.suggestions.items.isEmpty,
           suggestionsViewModel.suggestions.items.count > index {
            tableView.selectRowIndexes(IndexSet(arrayLiteral: index), byExtendingSelection: false)
        }
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

    func mouseDown(with event: NSEvent) -> NSEvent? {
        if event.window == view.window {
            return nil
        }

        return event
    }

    func mouseUp(with event: NSEvent) -> NSEvent? {
        if event.window == view.window {
            closeWindow()
            return nil
        }
        return event
    }

    private func closeWindow() {
        guard let window = view.window else {
            //todo os_log
            return
        }

        window.parent?.removeChildWindow(window)
        window.orderOut(nil)
    }

}

extension SuggestionsViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return suggestionsViewModel?.suggestions.items.count ?? 0
    }

}

extension SuggestionsViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let suggestionTableCellView = tableView.makeView(
                withIdentifier: NSUserInterfaceItemIdentifier(rawValue: SuggestionTableCellView.identifier), owner: self)
                as? SuggestionTableCellView else {
            //todo os_log
            return nil
        }

        guard let suggestion = suggestionsViewModel?.suggestions.items[row] else {
            //todo os_log
            return nil
        }

        suggestionTableCellView.display(suggestion)
        return suggestionTableCellView
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard let suggestionTableRowView = tableView.makeView(
                withIdentifier: NSUserInterfaceItemIdentifier(rawValue: SuggestionTableRowView.identifier), owner: self)
                as? SuggestionTableRowView else {
            //todo os_log
            return nil
        }
        return suggestionTableRowView
    }

}
