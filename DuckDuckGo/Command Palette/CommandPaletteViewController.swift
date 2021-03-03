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

    func activate() {
        switch self {
        case .tab(model: _, activate: let activate):
            activate()
        }
    }
}
struct CommandPaletteSection {
    let title: String
    let suggestions: [CommandPaletteSuggestion]
}
protocol CommandPaletteViewModelProtocol {
    var userInput: PassthroughSubject<String, Never> { get }
    var suggestionsPublisher: AnyPublisher<[CommandPaletteSection], Never> { get }
}

final class CommandPaletteViewController: NSViewController {
    @IBOutlet var backgroundView: NSVisualEffectView!
    @IBOutlet var textField: NSTextField!
    @IBOutlet var tableView: NSTableView!

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
            }
        }
    }
    private var objects: [Object]? {
        didSet {
            tableView.reloadData()
            DispatchQueue.main.async { [weak self] in
                self?.selectNextIfPossible(after: -1)
            }
        }
    }

    override func viewDidLoad() {
        backgroundView.wantsLayer = true
        backgroundView.layer!.cornerRadius = 20.0
        backgroundView.layer!.masksToBounds = true
    }

    override func viewWillAppear() {
        textField.stringValue = ""
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

        model.suggestionsPublisher.map {
            $0.reduce(into: [Object]()) {
                $0.append(contentsOf: [Object.title($1.title)] + $1.suggestions.map(Object.suggestion))
            }
        }.weakAssign(to: \.objects, on: self)
        .store(in: &cancellables)
    }

    func hide() {
        self.view.window?.parent?.removeChildWindow(self.view.window!)
        self.view.window?.orderOut(nil)
        self.representedObject = nil
    }

    func select(at index: Int) {
        tableView.selectRowIndexes(IndexSet(arrayLiteral: index), byExtendingSelection: false)
    }

    func selectNextIfPossible(after: Int? = nil) {
        guard let objects = objects,
              !objects.isEmpty
        else { return }

        var index = after ?? tableView.selectedRow
        repeat {
            index = (index + 1) % objects.count
        } while !objects[index].isSuggestion && index != tableView.selectedRow

        select(at: index)
    }

    func selectPreviousIfPossible() {
        guard let objects = objects,
              !objects.isEmpty
        else { return }

        var index = tableView.selectedRow
        repeat {
            index -= 1
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
        }
        return tableView.makeView(withIdentifier: identifier, owner: self)!
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard case .suggestion = objects![row] else { return nil }
        // swiftlint:disable force_cast
        return (tableView.makeView(withIdentifier: .suggestionRow, owner: self) as! NSTableRowView)
        // swiftlint:enable force_cast
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        switch objects![row] {
        case .title:
            return 17
        case .suggestion(.tab):
            return 58
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if case .leftMouseUp = NSApp.currentEvent?.type {
            confirmSelection()
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
    static let section = NSUserInterfaceItemIdentifier(rawValue: "SectionTitle")
    static let suggestionRow = NSUserInterfaceItemIdentifier(rawValue: SuggestionTableRowView.identifier)
}
