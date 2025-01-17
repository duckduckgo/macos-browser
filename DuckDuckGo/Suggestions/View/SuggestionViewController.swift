//
//  SuggestionViewController.swift
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
import History
import Suggestions

protocol SuggestionViewControllerDelegate: AnyObject {

    func suggestionViewControllerDidConfirmSelection(_ suggestionViewController: SuggestionViewController)

}

final class SuggestionViewController: NSViewController {

    weak var delegate: SuggestionViewControllerDelegate?

    @IBOutlet weak var backgroundView: ColorView!
    @IBOutlet weak var innerBorderView: ColorView!
    @IBOutlet weak var innerBorderViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var innerBorderViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var innerBorderViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var innerBorderViewTrailingConstraint: NSLayoutConstraint!

    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var tableViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var pixelPerfectConstraint: NSLayoutConstraint!

    let suggestionContainerViewModel: SuggestionContainerViewModel
    let isBurner: Bool

    required init?(coder: NSCoder) {
        fatalError("SuggestionViewController: Bad initializer")
    }

    required init?(coder: NSCoder,
                   suggestionContainerViewModel: SuggestionContainerViewModel,
                   isBurner: Bool) {
        self.suggestionContainerViewModel = suggestionContainerViewModel
        self.isBurner = isBurner

        super.init(coder: coder)
    }

    var suggestionResultCancellable: AnyCancellable?
    var selectionIndexCancellable: AnyCancellable?

    private var eventMonitorCancellables = Set<AnyCancellable>()
    private var appObserver: Any?

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self

        setupTableView()
        addTrackingArea()
        subscribeToSuggestionResult()
        subscribeToSelectionIndex()
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        self.view.window!.isOpaque = false
        self.view.window!.backgroundColor = .clear

        addEventMonitors()
        tableView.rowHeight = suggestionContainerViewModel.isHomePage ? 34 : 28
    }

    override func viewDidDisappear() {
        eventMonitorCancellables.removeAll()
        clearSelection()
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        // Make sure the table view width equals the encapsulating scroll view
        tableView.sizeToFit()
        let column = tableView.tableColumns.first
        column?.width = tableView.frame.width
    }

    private func setupTableView() {
        tableView.style = .plain
        tableView.setAccessibilityIdentifier("SuggestionViewController.tableView")
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

    @IBAction func confirmButtonAction(_ sender: NSButton) {
        delegate?.suggestionViewControllerDidConfirmSelection(self)
        closeWindow()
    }

    @IBAction func removeButtonAction(_ sender: NSButton) {
        guard let cell = sender.superview as? SuggestionTableCellView,
        let suggestion = cell.suggestion else {
            assertionFailure("Correct cell or url are not available")
            return
        }

        removeHistory(for: suggestion)
    }

    private func addEventMonitors() {
        eventMonitorCancellables.removeAll()

        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification).sink { [weak self] _ in
            self?.closeWindow()
        }.store(in: &eventMonitorCancellables)
    }

    private func subscribeToSuggestionResult() {
        suggestionResultCancellable = suggestionContainerViewModel.suggestionContainer.$result
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
            self?.displayNewSuggestions()
        }
    }

    private func subscribeToSelectionIndex() {
        selectionIndexCancellable = suggestionContainerViewModel.$selectionIndex.receive(on: DispatchQueue.main).sink { [weak self] _ in
            if let weakSelf = self {
                weakSelf.selectRow(at: weakSelf.suggestionContainerViewModel.selectionIndex)
            }
        }
    }

    private func displayNewSuggestions() {
        defer {
            selectedRowCache = nil
        }

        guard suggestionContainerViewModel.numberOfSuggestions > 0 else {
            closeWindow()
            tableView.reloadData()
            return
        }

        // Remove the second reload that causes visual glitch in the beginning of typing
        if suggestionContainerViewModel.suggestionContainer.result != nil {
            updateHeight()
            tableView.reloadData()

            // Select at the same position where the suggestion was removed
            if let selectedRowCache = selectedRowCache {
                suggestionContainerViewModel.select(at: selectedRowCache)
            }

            self.selectRow(at: self.suggestionContainerViewModel.selectionIndex)
        }
    }

    private func selectRow(at index: Int?) {
        if tableView.selectedRow == index {
            if let index, let cell = tableView.view(atColumn: 0, row: index, makeIfNecessary: false) as? SuggestionTableCellView {
                // Show the delete button if necessary
                cell.updateDeleteImageViewVisibility()
            }
            return
        }

        guard let index = index,
              index >= 0,
              suggestionContainerViewModel.numberOfSuggestions != 0,
              index < suggestionContainerViewModel.numberOfSuggestions else {
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

    private func updateHeight() {
        guard suggestionContainerViewModel.numberOfSuggestions > 0 else {
            tableViewHeightConstraint.constant = 0
            return
        }

        let rowHeight = tableView.rowHeight

        tableViewHeightConstraint.constant = CGFloat(suggestionContainerViewModel.numberOfSuggestions) * rowHeight
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

    var selectedRowCache: Int?

    private func removeHistory(for suggestion: Suggestion) {
        assert(suggestion.isHistoryEntry)

        guard let url = suggestion.url else {
            assertionFailure("URL not available")
            return
        }

        selectedRowCache = tableView.selectedRow

        HistoryCoordinator.shared.removeUrlEntry(url) { [weak self] error in
            guard let self = self, error == nil else {
                return
            }

            if let userStringValue = suggestionContainerViewModel.userStringValue {
                suggestionContainerViewModel.isTopSuggestionSelectionExpected = false
                self.suggestionContainerViewModel.suggestionContainer.getSuggestions(for: userStringValue, useCachedData: true)
            } else {
                self.suggestionContainerViewModel.removeSuggestionFromResult(suggestion: suggestion)
            }
        }
    }

}

extension SuggestionViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return suggestionContainerViewModel.numberOfSuggestions
    }

}

extension SuggestionViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: SuggestionTableCellView.identifier, owner: self) as? SuggestionTableCellView ?? SuggestionTableCellView()

        guard let suggestionViewModel = suggestionContainerViewModel.suggestionViewModel(at: row) else {
            assertionFailure("SuggestionViewController: Failed to get suggestion")
            return nil
        }

        cell.display(suggestionViewModel, isBurner: self.isBurner)
        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard let suggestionTableRowView = tableView.makeView(
                withIdentifier: NSUserInterfaceItemIdentifier(rawValue: SuggestionTableRowView.identifier), owner: self)
                as? SuggestionTableRowView else {
            assertionFailure("SuggestionViewController: Making of table row view failed")
            return nil
        }
        return suggestionTableRowView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if tableView.selectedRow == -1 {
            suggestionContainerViewModel.clearSelection()
            return
        }

        if suggestionContainerViewModel.selectionIndex != tableView.selectedRow {
            suggestionContainerViewModel.select(at: tableView.selectedRow)
        }
    }

}
