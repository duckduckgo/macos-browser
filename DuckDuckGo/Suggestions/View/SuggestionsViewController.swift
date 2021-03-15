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

    func shouldCloseSuggestionsWindow(forMouseEvent event: NSEvent) -> Bool
    func suggestionsViewControllerDidConfirmSelection(_ suggestionsViewController: SuggestionsViewController)

}

class SuggestionsViewController: NSViewController {

    weak var delegate: SuggestionsViewControllerDelegate?

    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var tableViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var pixelPerfectConstraint: NSLayoutConstraint!

    let suggestionsViewModel: SuggestionsViewModel

    required init?(coder: NSCoder) {
        fatalError("SuggestionsViewController: Bad initializer")
    }

    required init?(coder: NSCoder, suggestionsViewModel: SuggestionsViewModel) {
        self.suggestionsViewModel = suggestionsViewModel

        super.init(coder: coder)
    }

    var suggestionsCancellable: AnyCancellable?
    var selectionIndexCancellable: AnyCancellable?

    private var mouseUpEventsMonitor: Any?
    private var mouseDownEventsMonitor: Any?
    private var appObserver: Any?

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self

        setupTableView()
        addTrackingArea()
        subscribeToSuggestions()
        subscribeToSelectionIndex()
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        self.view.window!.isOpaque = false
        self.view.window!.backgroundColor = .clear
        
        addMonitors()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        removeMouseEventsMonitor()
        clearSelection()
    }

    private func setupTableView() {
        if #available(OSX 11.0, *) {
            tableView.style = .plain
        }
    }

    private func addTrackingArea() {
        let trackingOptions: NSTrackingArea.Options = [ .activeInActiveApp,
                                                        .mouseEnteredAndExited,
                                                        .enabledDuringMouseDrag,
                                                        .mouseMoved,
                                                        .inVisibleRect ]
        let trackingArea = NSTrackingArea(rect: tableView.frame, options: trackingOptions, owner: self, userInfo: nil)
        tableView.addTrackingArea(trackingArea)
    }

    private func addMonitors() {
        let upEventTypes: NSEvent.EventTypeMask = [.leftMouseUp, .rightMouseUp]
        mouseUpEventsMonitor = NSEvent.addLocalMonitorForEvents(matching: upEventTypes) { [weak self] event in
            self?.mouseUp(with: event)
        }

        let downEventTypes: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]
        mouseDownEventsMonitor = NSEvent.addLocalMonitorForEvents(matching: downEventTypes) { [weak self] event in
            self?.mouseDown(with: event)
        }

        appObserver = NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification,
                                                             object: nil,
                                                             queue: nil) { [weak self] _ in
            self?.closeWindow()
        }
    }

    private func removeMouseEventsMonitor() {
        if let upEventMonitor = mouseUpEventsMonitor {
            NSEvent.removeMonitor(upEventMonitor)
            mouseUpEventsMonitor = nil
        }

        if let downEventMonitor = mouseDownEventsMonitor {
            NSEvent.removeMonitor(downEventMonitor)
            mouseDownEventsMonitor = nil
        }
    }

    private func subscribeToSuggestions() {
        suggestionsCancellable = suggestionsViewModel.suggestions.$items.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.displayNewSuggestions()
        }
    }

    private func subscribeToSelectionIndex() {
        selectionIndexCancellable = suggestionsViewModel.$selectionIndex.receive(on: DispatchQueue.main).sink { [weak self] _ in
            if let weakSelf = self {
                weakSelf.selectRow(at: weakSelf.suggestionsViewModel.selectionIndex)
            }
        }
    }

    private func displayNewSuggestions() {
        guard suggestionsViewModel.numberOfSuggestions > 0 else {
            closeWindow()
            tableView.reloadData()
            return
        }

        // Remove the second reload that causes visual glitch in the beginning of typing
        if suggestionsViewModel.suggestions.items != nil {
            updateHeight()
            tableView.reloadData()
            self.selectRow(at: self.suggestionsViewModel.selectionIndex)
        }
    }

    private func selectRow(at index: Int?) {
        if tableView.selectedRow == index { return }

        guard let index = index,
              index >= 0,
              suggestionsViewModel.numberOfSuggestions != 0,
              index < suggestionsViewModel.numberOfSuggestions else {
            self.clearSelection()
            return
        }

        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
    }

    private func selectRow(at point: NSPoint) {
        let flippedPoint = view.convert(point, to: tableView)
        let row = tableView.row(at: flippedPoint)
        selectRow(at: row)
    }

    private func clearSelection() {
        tableView.deselectAll(self)
    }

    override func mouseMoved(with event: NSEvent) {
        selectRow(at: event.locationInWindow)
    }

    override func mouseExited(with event: NSEvent) {
        clearSelection()
    }

    func mouseDown(with event: NSEvent) -> NSEvent? {
        if event.window === view.window {
            return nil
        }
        if delegate?.shouldCloseSuggestionsWindow(forMouseEvent: event) ?? true {
            closeWindow()
        }
        
        return event
    }

    func mouseUp(with event: NSEvent) -> NSEvent? {
        if event.window === view.window,
           tableView.bounds.contains(tableView.convert(event.locationInWindow, from: nil)) {

            closeWindow()
            delegate?.suggestionsViewControllerDidConfirmSelection(self)
            return nil
        }
        return event
    }

    private func updateHeight() {
        guard suggestionsViewModel.numberOfSuggestions > 0 else {
            tableViewHeightConstraint.constant = 0
            return
        }

        let rowHeight = tableView.rowHeight

        tableViewHeightConstraint.constant = CGFloat(suggestionsViewModel.numberOfSuggestions) * rowHeight
            + (tableView.enclosingScrollView?.contentInsets.top ?? 0)
            + (tableView.enclosingScrollView?.contentInsets.bottom ?? 0)
    }

    private func closeWindow() {
        guard let window = view.window else {
            return
        }

        window.parent?.removeChildWindow(window)
        window.orderOut(nil)
    }

}

extension SuggestionsViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return suggestionsViewModel.numberOfSuggestions
    }

}

extension SuggestionsViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let suggestionTableCellView = tableView.makeView(
                withIdentifier: NSUserInterfaceItemIdentifier(rawValue: SuggestionTableCellView.identifier), owner: self)
                as? SuggestionTableCellView else {
            assertionFailure("SuggestionsViewController: Making of table cell view failed")
            return nil
        }

        guard let suggestionViewModel = suggestionsViewModel.suggestionViewModel(at: row) else {
            assertionFailure("SuggestionsViewController: Failed to get suggestion")
            return nil
        }

        suggestionTableCellView.display(suggestionViewModel)
        return suggestionTableCellView
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard let suggestionTableRowView = tableView.makeView(
                withIdentifier: NSUserInterfaceItemIdentifier(rawValue: SuggestionTableRowView.identifier), owner: self)
                as? SuggestionTableRowView else {
            assertionFailure("SuggestionsViewController: Making of table row view failed")
            return nil
        }
        return suggestionTableRowView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if tableView.selectedRow == -1 {
            suggestionsViewModel.clearSelection()
            return
        }

        if suggestionsViewModel.selectionIndex != tableView.selectedRow {
            suggestionsViewModel.select(at: tableView.selectedRow)
        }
    }

}
