//
//  CommandPaletteViewController.swift
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

final class CommandPaletteWindow: NSPanel {
    override var canBecomeKey: Bool {
        true
    }
    override var canBecomeMain: Bool {
        false
    }
}

enum CommandPaletteSuggestion: Equatable {
    case tab(model: TabViewModel, activate: () -> Void)
    case searchResult(model: SearchResult, activate: () -> Void)
    case fulltextSearchResult(model: FullTextTabSearchResult, activate: () -> Void)

    func activate() {
        switch self {
        case .tab(model: _, activate: let activate),
             .searchResult(model: _, activate: let activate),
             .fulltextSearchResult(model: _, activate: let activate):
            activate()
        }
    }

    static func == (lhs: CommandPaletteSuggestion, rhs: CommandPaletteSuggestion) -> Bool {
        switch (lhs, rhs) {
        case (.tab(model: let model1, activate: _), .tab(let model2, _)):
            return model1.tab == model2.tab
        case (.searchResult(model: let model1, activate: _), .searchResult(model: let model2, activate: _)):
            return model1 == model2
        case (.fulltextSearchResult(model: let model1, activate: _), .fulltextSearchResult(model: let model2, activate: _)):
            return model1.tabViewModel.tab == model2.tabViewModel.tab
        case (.tab, _), (.searchResult, _), (.fulltextSearchResult, _):
            return false
        }
    }
}

struct CommandPaletteSection {
    enum Section: String, CaseIterable {
        case help = "Help"
        case currentWindowTabs = "Active Window"
        case otherWindowsTabs = "All Tabs"
        case fulltextSearch = "Fulltext Search"
        case bookmarks = "Bookmarks"
        case searchResults = "DuckDuckGo Search Results"
        case instantAnswers = "Instant Answers"

        case inspector = "Developer Tools"
        case copyURL = "Copy URL"
    }

    let section: Section
    let suggestions: [CommandPaletteSuggestion]
}
protocol CommandPaletteViewModelProtocol {
    var userInput: PassthroughSubject<String, Never> { get }
    var suggestionsPublisher: AnyPublisher<[CommandPaletteSection], Never> { get }
    var isLoading: Bool { get }
    var isLoadingPublisher: AnyPublisher<Bool, Never> { get }
}

final class CommandPaletteViewController: NSViewController {
    @IBOutlet var backgroundView: NSVisualEffectView!
    @IBOutlet var textField: NSTextField!
    @IBOutlet var tableView: NSTableView!
    @IBOutlet var viewHeightConstraint: NSLayoutConstraint!
    
    @objc dynamic var textFieldIsEmpty: Bool = true

    private lazy var tempSnippetCellView: NSTableCellView = {
        // swiftlint:disable force_cast
        tableView.makeView(withIdentifier: .snippetCell, owner: nil) as! NSTableCellView
        // swiftlint:enable force_cast
    }()

    override var representedObject: Any? {
        didSet {
            bind()
        }
    }

    private var model: CommandPaletteViewModelProtocol? {
        // swiftlint:disable force_cast
        representedObject as! CommandPaletteViewModelProtocol?
        // swiftlint:enable force_cast
    }

    private var cancellables = Set<AnyCancellable>()

    enum Object {
        case title(String)
        case suggestion(CommandPaletteSuggestion)
        case loading

        var isSuggestion: Bool {
            if case .suggestion = self {
                return true
            }
            return false
        }
        var object: Any {
            switch self {
            case .title(let title):
                return title
            case .suggestion(.tab(model: let model, activate: _)):
                return model
            case .suggestion(.searchResult(model: let model, activate: _)):
                return model
            case .suggestion(.fulltextSearchResult(model: let model, activate: _)):
                return model
            case .loading:
                return ""
            }
        }
    }
    private var objects: [Object]? {
        didSet {
            tableView.reloadData()
            updateHeight()
            DispatchQueue.main.async { [weak self] in
                self?.selectNextIfPossible(after: -1)
                self?.tableView.enclosingScrollView?.flashScrollers()
            }
        }
    }

    override func viewDidLoad() {
        backgroundView.wantsLayer = true
        backgroundView.layer!.cornerRadius = 8.0
        backgroundView.layer!.masksToBounds = true
        backgroundView.layer!.borderWidth = 1.0
        backgroundView.layer!.borderColor = NSColor.separatorColor.cgColor
        addTrackingArea()
    }

    override func viewWillAppear() {
        textField.stringValue = ""
        textFieldIsEmpty = true
        representedObject = CommandPaletteViewModel()
    }

    override func viewDidAppear() {
        textField.makeMeFirstResponder()
        NotificationCenter.default
            .publisher(for: NSWindow.didBecomeKeyNotification)
            .sink { [weak self] notification in
                guard let self = self,
                      let window = notification.object as? NSWindow,
                      window !== self.view.window
                else { return }

                if window.nextResponder is LinkPreviewWindowController,
                   self.linkPreviewViewController != nil {

                    // Link Preview Controller detached
                    self.linkPreviewViewController = nil
                    // bring focus back
                    self.view.window?.makeKeyAndOrderFront(nil)

                } else if self.linkPreviewViewController == nil {
                    self.hide()
                }

            }.store(in: &self.cancellables)
    }

    private func bind() {
        cancellables = []
        guard let model = model else { return }

        model.suggestionsPublisher.combineLatest(model.isLoadingPublisher).map {
            $0.0.reduce(into: [Object]()) {
                $0.append(contentsOf: [Object.title($1.section.rawValue)] + $1.suggestions.map(Object.suggestion))
            } + ($0.1 /* isLoading */ ? [Object.loading] : [])
        }.weakAssign(to: \.objects, on: self)
        .store(in: &cancellables)

        model.userInput.map(\.isEmpty)
            .assign(to: \.textFieldIsEmpty, on: self)
        .store(in: &cancellables)

        NSEvent.localEvents(for: .leftMouseDown)
            .sink { [weak self] in self?.mouseDown($0) }
            .store(in: &cancellables)

        NSEvent.localEvents(for: .leftMouseUp)
            .sink { [weak self] in self?.mouseUp($0) }
            .store(in: &cancellables)
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

    func hide() {
        self.linkPreviewViewController?.dismiss(nil)
        self.tooltipWindowController?.tooltipViewController.dismiss(nil)

        self.view.window?.parent?.removeChildWindow(self.view.window!)
        self.view.window?.orderOut(nil)
        self.representedObject = nil
    }

    private func updateHeight() {
        guard let window = self.view.window,
              let parentWindow = window.parent
        else { return }

        let tableHeight: CGFloat
        if (objects?.count ?? 0) > 0 {
            tableHeight = tableView.frame.height
                + (tableView.enclosingScrollView?.contentInsets.top ?? 0)
                + (tableView.enclosingScrollView?.contentInsets.bottom ?? 0)
        } else {
            tableHeight = 0
        }

        viewHeightConstraint.constant = min(tableHeight + 42,
                                            max(window.frame.maxY - parentWindow.frame.minY, 80))
    }

    override func mouseMoved(with event: NSEvent) {
        selectRow(at: event.locationInWindow)
    }

    override func mouseExited(with event: NSEvent) {

    }

    func mouseDown(_ output: NSEvent.LocalEvents.Output) {
        if output.event.window === view.window {
            output.handled()
            return
        } else if output.event.window?.contentViewController is LinkPreviewViewController {
            return
        }

        hide()
    }

    func mouseUp(_ output: NSEvent.LocalEvents.Output) {
        guard output.event.window === view.window,
              tableView.bounds.contains(tableView.convert(output.event.locationInWindow, from: nil))
        else {
            return
        }

        hide()
        confirmSelection()
        output.handled()
    }

    var linkPreviewViewController: LinkPreviewViewController?
    private func displayLinkPreview(for url: URL, from rect: CGRect) {
        guard model?.isLoading == false,
              let parent = self.view.window?.parent?.contentViewController
        else { return }

        linkPreviewViewController?.dismiss(nil)
        tooltipWindowController?.tooltipViewController.dismiss(nil)

        let controller = LinkPreviewViewController.create(for: url)
        controller.delegate = self
        self.linkPreviewViewController = controller

        let flipped = view.convert(rect, from: tableView)
        let converted = view.convert(flipped, to: nil)
        let screen = view.window!.convertToScreen(converted)
        let windowRect = parent.view.window!.convertFromScreen(screen)
        let targetRect = parent.view.convert(windowRect, from: nil)

        parent.present(controller, asPopoverRelativeTo: targetRect, of: parent.view, preferredEdge: .maxX, behavior: .transient)

        previewMatchesSelection = true
    }

    private var tooltipWindowController: TooltipWindowController?

    func showTooltip(for tabViewModel: TabViewModel, from rect: CGRect) {
//        if tooltipWindowController == nil {
//            tooltipWindowController = { () -> TooltipWindowController in
//                // swiftlint:disable force_cast
//                let storyboard = NSStoryboard(name: "Tooltip", bundle: nil)
//                return storyboard.instantiateController(withIdentifier: "TooltipWindowController") as! TooltipWindowController
//                // swiftlint:enable force_cast
//            }()
//        }
//        linkPreviewViewController?.dismiss(nil)
//        tooltipWindowController!.tooltipViewController.dismiss(nil)
//
//        tooltipWindowController!.tooltipViewController.display(tabViewModel: tabViewModel)
//
//        self.present(tooltipWindowController!.tooltipViewController, asPopoverRelativeTo: rect, of: tableView, preferredEdge: .maxX, behavior: .transient)
    }

    var previewMatchesSelection = false
    func displayPreviewAfterDelay(forItemAt index: Int) {
        previewMatchesSelection = false
        guard objects?.indices.contains(index) == true,
            case .suggestion(let suggestion) = objects![index]
        else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self,
                  self.tableView.selectedRow == index,
                  case .suggestion(suggestion) = self.objects![index]
            else { return }

            let rect = self.tableView.rect(ofRow: index)
            switch suggestion {
            case .searchResult(model: let searchResult, activate: _):
                guard let url = searchResult.url else { break }

                self.displayLinkPreview(for: url, from: rect)

            case .tab(model: let model, activate: _):
                self.showTooltip(for: model, from: rect)

            case .fulltextSearchResult(model: let model, activate: _):
                self.showTooltip(for: model.tabViewModel, from: rect)
            }
        }
    }

    var selectedSuggestion: CommandPaletteSuggestion?
    func select(at index: Int) {
        guard objects?.indices.contains(index) == true,
              case .suggestion(let suggestion) = objects![index]
        else {
            linkPreviewViewController?.dismiss(nil)
            tooltipWindowController?.tooltipViewController.dismiss(nil)
            tableView.deselectAll(nil)
            selectedSuggestion = nil
            return
        }
        if case .suggestion(selectedSuggestion) = objects![index],
           tableView.selectedRow == index {
            return
        }

        self.selectedSuggestion = suggestion
        tableView.selectRowIndexes(IndexSet(arrayLiteral: index), byExtendingSelection: false)
        tableView.scrollRowToVisible(index)

        displayPreviewAfterDelay(forItemAt: index)
    }

    private func selectRow(at point: NSPoint) {
        let flippedPoint = view.convert(point, to: tableView)
        let row = tableView.row(at: flippedPoint)
        guard objects?.indices.contains(row) == true,
              case .suggestion = objects![row]
        else { return }
        select(at: row)
    }

    func selectNextIfPossible(after: Int? = nil) {
        guard let objects = objects,
              !objects.isEmpty
        else {
            select(at: -1)
            return
        }

        let after = after ?? tableView.selectedRow
        var index = after
        repeat {
            index += 1
            if index >= objects.count {
                if after < 0 {
                    break
                }
                index = 0
            }
        } while !objects[index].isSuggestion && index != after

        select(at: index)
    }

    func selectFirst() {
        selectNextIfPossible(after: -1)
    }

    func selectPreviousIfPossible(before: Int? = nil) {
        guard let objects = objects,
              !objects.isEmpty
        else { return }

        let before = before ?? tableView.selectedRow
        var index = before
        repeat {
            index -= 1
            if before < 0 && index == -1 {
                break
            }
            if index < 0 {
                index = tableView.numberOfRows - 1
            }
        } while !objects[index].isSuggestion && index != before

        select(at: index)
    }

    func selectLast() {
        selectPreviousIfPossible(before: -1)
    }

    func confirmSelection() {
        defer {
            hide()
        }

        if previewMatchesSelection,
           let previewController = self.linkPreviewViewController,
           previewController.presentingViewController != nil {

            previewController.pinToScreen(nil)

            return
        }

        guard let objects = objects,
              objects.indices.contains(tableView.selectedRow)
            else { return }

        switch objects[tableView.selectedRow] {
        case .suggestion(let suggestion):
            suggestion.activate()
        default:
            return
        }
    }

    @IBAction func clearValue(_ sender: Any) {
        textField.stringValue = ""
    }

}

extension CommandPaletteViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        objects?.count ?? 0
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return objects![row].object
    }

}

extension CommandPaletteViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier: NSUserInterfaceItemIdentifier
        switch objects![row] {
        case .title:
            identifier = .section
        case .suggestion(.tab):
            identifier = .tab
        case .suggestion(.searchResult):
            identifier = .snippetCell
        case .suggestion(.fulltextSearchResult):
            identifier = .snippetCell
        case .loading:
            identifier = .loadingCell
        }
        return tableView.makeView(withIdentifier: identifier, owner: self)!
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let identifier: NSUserInterfaceItemIdentifier
        switch objects![row] {
        case .title:
            identifier = .sectionRow
        case .suggestion:
            identifier = .suggestionRow
        default:
            return nil
        }
        // swiftlint:disable force_cast
        return (tableView.makeView(withIdentifier: identifier, owner: self) as! NSTableRowView)
        // swiftlint:enable force_cast
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        switch objects![row] {
        case .title:
            return 25
        case .suggestion(.tab):
            return 45
        case .loading:
            return 24
        case .suggestion(.searchResult(model: let model, activate: _)):
            tempSnippetCellView.objectValue = model
            tempSnippetCellView.layoutSubtreeIfNeeded()
            return tempSnippetCellView.frame.height
        case .suggestion(.fulltextSearchResult(model: let model, activate: _)):
            tempSnippetCellView.objectValue = model
            tempSnippetCellView.layoutSubtreeIfNeeded()
            return tempSnippetCellView.frame.height
        }
    }

}

extension CommandPaletteViewController: NSTextFieldDelegate {

    func controlTextDidChange(_ obj: Notification) {
        model!.userInput.send( textField.stringValue )
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.cancelOperation(_:)):
            self.hide()
            return true
        case #selector(NSResponder.moveDown(_:)):
            self.selectNextIfPossible()
            return true
        case #selector(NSResponder.moveToEndOfDocument(_:)):
            self.selectLast()
            return true
        case #selector(NSResponder.moveUp(_:)):
            self.selectPreviousIfPossible()
            return true
        case #selector(NSResponder.moveToBeginningOfDocument(_:)):
            self.selectFirst()
            return true

        case #selector(NSResponder.insertNewline(_:)):
            self.confirmSelection()
            return true

        default:
            return false
        }
    }

}

extension CommandPaletteViewController: LinkPreviewViewControllerDelegate {
    func linkPreviewViewController(_ controller: LinkPreviewViewController, requestedNewTab url: URL?) {
        WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController!.browserTabViewController?
            .openNewTab(with: url, selected: true)
            ?? {
                if let url = url {
                    WindowsManager.openNewWindow(with: url)
                } else {
                    WindowsManager.openNewWindow()
                }
            }()
    }
    func linkPreviewViewController(_ controller: LinkPreviewViewController, willDetachWindow window: NSWindow) {
//        var observer: NSKeyValueObservation?
//        observer = window.observe(\.isKeyWindow) { window, _ in
//            if window.isKeyWindow, let _ = observer {
//                self.view.window?.makeKeyAndOrderFront(nil)
//                observer = nil
//            }
//        }
//        self.linkPreviewViewController = nil
    }
}

private extension NSUserInterfaceItemIdentifier {
    static let tab = NSUserInterfaceItemIdentifier(rawValue: "TabTableCellView")
    static let snippetCell = NSUserInterfaceItemIdentifier(rawValue: "SnippetTableCellView")
    static let section = NSUserInterfaceItemIdentifier(rawValue: "SectionTitle")
    static let suggestionRow = NSUserInterfaceItemIdentifier(rawValue: SuggestionTableRowView.identifier)
    static let sectionRow = NSUserInterfaceItemIdentifier(rawValue: "SectionRow")
    static let loadingCell = NSUserInterfaceItemIdentifier(rawValue: "Loading")
}
