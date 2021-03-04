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

enum CommandPaletteSuggestion {
    case tab(model: TabViewModel, activate: () -> Void)
    case searchResult(model: SearchResult, activate: () -> Void)

    func activate() {
        switch self {
        case .tab(model: _, activate: let activate):
            activate()
        case .searchResult(model: _, activate: let activate):
            activate()
        }
    }
}

struct CommandPaletteSection {
    enum Section: String {
        case currentWindowTabs = "Active Window"
        case otherWindowsTabs = "All Tabs"
        case searchResults = "DuckDuckGo Search Results"
    }

    let section: Section
    let suggestions: [CommandPaletteSuggestion]
}
protocol CommandPaletteViewModelProtocol {
    var userInput: PassthroughSubject<String, Never> { get }
    var suggestionsPublisher: AnyPublisher<[CommandPaletteSection], Never> { get }
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
    }

    override func viewWillAppear() {
        textField.stringValue = ""
        textFieldIsEmpty = true
        representedObject = CommandPaletteViewModel()
    }

    override func viewDidAppear() {
        textField.makeMeFirstResponder()
        NotificationCenter.default
            .publisher(for: NSWindow.didResignKeyNotification, object: self.view.window!)
            .sink { [weak self] _ in
                self?.hide()
            }.store(in: &self.cancellables)
    }

    private func bind() {
        guard let model = model else {
            cancellables = []
            return
        }

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

    func hide() {
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

    func mouseDown(_ output: NSEvent.LocalEvents.Output) {
        guard output.event.window !== view.window else {
            output.handled()
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

    func select(at index: Int) {
        tableView.selectRowIndexes(IndexSet(arrayLiteral: index), byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
    }

    func selectNextIfPossible(after: Int? = nil) {
        guard let objects = objects,
              !objects.isEmpty
        else { return }

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

    func selectPreviousIfPossible() {
        guard let objects = objects,
              !objects.isEmpty
        else { return }

        var index = tableView.selectedRow
        repeat {
            index -= 1
            if tableView.selectedRow == -1 && index == -1 {
                break
            }
            if index < 0 {
                index = tableView.numberOfRows - 1
            }
        } while !objects[index].isSuggestion && index != tableView.selectedRow

        select(at: index)
    }

    func confirmSelection() {
        defer {
            hide()
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
        case #selector(NSResponder.moveUp(_:)):
            self.selectPreviousIfPossible()
            return true

        case #selector(NSResponder.insertNewline(_:)):
            self.confirmSelection()
            return true

        default:
            return false
        }
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
