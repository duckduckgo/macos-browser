//
//  AddressBarTextEditor.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import AppKit
import Common
import Foundation

final class AddressBarTextEditor: NSTextView {

    fileprivate var addressBar: AddressBarTextField? {
        guard let delegate else { return nil }
        guard let addressBar = delegate as? AddressBarTextField else {
            assertionFailure("AddressBarTextEditor: unexpected kind of delegate")
            return nil
        }
        return addressBar
    }

    @available(macOS 12.0, *)
    override var textLayoutManager: NSTextLayoutManager? {
        if let textLayoutManager = super.textLayoutManager,
           !(textLayoutManager.textSelectionNavigation is AddressBarTextSelectionNavigation) {
            textLayoutManager.textSelectionNavigation = AddressBarTextSelectionNavigation(dataSource: textLayoutManager)
        }

        return super.textLayoutManager
    }

    override func paste(_ sender: Any?) {
        // Fixes an issue when url-name instead of url is pasted
        if let url = NSPasteboard.general.url {
            super.pasteAsPlainText(url.absoluteString)
        } else {
            super.paste(sender)
        }
    }

    override func copy(_ sender: Any?) {
        CopyHandler().copy(sender)
    }

    // MARK: - Exclude “ – Search with DuckDuckGo” suffix from selection range

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        let string = self.string
        let range = ranges.first.flatMap { Range($0.rangeValue, in: string) }

        let selectableRange = addressBar?.stringValueWithoutSuffixRange
        let clamped = selectableRange.flatMap { range?.clamped(to: $0) } ?? range
        let result = clamped.map { [NSValue(range: NSRange($0, in: string))] } ?? []

        super.setSelectedRanges(result, affinity: affinity, stillSelecting: stillSelectingFlag)
    }

    override func characterIndexForInsertion(at point: NSPoint) -> Int {
        let index = super.characterIndexForInsertion(at: point)
        let adjustedRange = selectionRange(forProposedRange: NSRange(location: index, length: 0), granularity: .selectByCharacter)
        return adjustedRange.location
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        guard let addressBar, let string = string as? String else {
            super.insertText(string, replacementRange: replacementRange)
            return
        }
        breakUndoCoalescingIfNeeded(for: InputType(string))

        addressBar.textView(self, userTypedString: string, at: replacementRange.location == NSNotFound ? self.selectedRange() : replacementRange) {
            super.insertText(string, replacementRange: replacementRange)
        }
    }

    func selectToTheEnd(from offset: Int) {
        let string = self.string
        let startIndex = string.index(string.startIndex, offsetBy: min(string.count, offset))
        let range = NSRange(startIndex..., in: string)

        self.setSelectedRanges([NSValue(range: range)], affinity: .downstream /* rtl */, stillSelecting: false)
    }

    // MARK: - Moving selection by word

    @available(macOS, deprecated: 12.0, message: "Move this logic to AddressBarTextSelectionNavigation")
    override func selectionRange(forProposedRange proposedCharRange: NSRange, granularity: NSSelectionGranularity) -> NSRange {
        let string = self.string
        guard let selectableRange = addressBar?.stringValueWithoutSuffixRange,
              var clampedRange = Range(proposedCharRange, in: string)?.clamped(to: selectableRange) else { return proposedCharRange }
        guard !selectableRange.isEmpty else { return NSRange(selectableRange, in: string) }

        let range: Range<String.Index>
        switch granularity {
        case .selectByParagraph:
            // select all
            range = selectableRange

        case .selectByWord:
            // if at the end of string: adjust proposed selection to include at least the last character
            if clampedRange.lowerBound == selectableRange.upperBound {
                clampedRange = string.index(selectableRange.upperBound, offsetBy: -1)..<selectableRange.upperBound
            } else if clampedRange.isEmpty /* assuming clampedRange.upperBound < selectableRange.upperBound - as of the previous check */ {
                // include at least one character in selection
                clampedRange = clampedRange.lowerBound..<string.index(after: clampedRange.lowerBound)
            }

            // index of separator before the first selected character (including the character itself)
            let startIndex = min(string.rangeOfCharacter(from: .urlWordBoundCharacters,
                                                         options: .backwards,
                                                         // search from the first proposed range character INCLUSIVE to the beginning of the selectable range
                                                         range: selectableRange.lowerBound..<string.index(after: clampedRange.lowerBound))?.upperBound
                                 // separator not found: use the selectable range start index
                                 ?? selectableRange.lowerBound,
                                 // if the clicked character is a separator itself - selection should start from the character
                                 clampedRange.lowerBound)
            // index of separator after the last selected character (including the character itself)
            let endIndex = max(string.rangeOfCharacter(from: .urlWordBoundCharacters,
                                                       options: [],
                                                       // search from the last proposed range character INCLUSIVE to the end of the selectable range
                                                       range: string.index(before: clampedRange.upperBound)..<selectableRange.upperBound)?.lowerBound
                               // separator not found: use the selectable range end index
                               ?? selectableRange.upperBound,
                               // if the clicked character is a separator itself - selection should end with the character
                               clampedRange.upperBound)
            range = startIndex..<endIndex

        case .selectByCharacter: fallthrough
        @unknown default:
            // adjust caret location only
            range = clampedRange
        }

        return NSRange(range, in: string)
    }

    private func nextWordSelectionIndex(backwards: Bool) -> Int? {
        let string = self.string

        guard let selectableRange = addressBar?.stringValueWithoutSuffixRange,
              let selectedRange = Range(selectedRange(), in: string)?.clamped(to: selectableRange) else { return nil }

        var index = backwards ? selectedRange.lowerBound : selectedRange.upperBound
        var searchRange: Range<String.Index> {
            backwards ? selectableRange.lowerBound..<index : index..<selectableRange.upperBound
        }

        // first skip all punctuation (word boundary) characters
        // then skip word characters and boundary characters (up to the next word boundary)
        for charset in [CharacterSet.urlWordBoundCharacters, .urlWordCharacters] {
            if let range = string.rangeOfCharacter(from: charset.inverted, options: backwards ? .backwards : [], range: searchRange) {
                index = backwards ? range.upperBound : range.lowerBound
            } else {
                index = backwards ? selectableRange.lowerBound : selectableRange.upperBound
                break
            }
        }

        return NSRange(index..<index, in: string).location
    }

    override func moveWordRight(_ sender: Any?) {
        guard let index = nextWordSelectionIndex(backwards: false) else { return }

        self.selectedRange = NSRange(location: index, length: 0)
    }

    override func moveWordLeft(_ sender: Any?) {
        guard let index = nextWordSelectionIndex(backwards: true) else { return }

        self.selectedRange = NSRange(location: index, length: 0)
    }

    override func moveWordRightAndModifySelection(_ sender: Any?) {
        let selectedRange = self.selectedRange()
        guard selectionAffinity == .downstream || selectedRange.length == 0 else {
            // current selection is from right to left: reset selection to the upper bound
            self.selectedRange = NSRange(location: selectedRange.upperBound, length: 0)
            return
        }
        guard let index = nextWordSelectionIndex(backwards: false) else { return }

        let range = NSRange(location: selectedRange.location, length: index - selectedRange.location)
        self.setSelectedRange(range, affinity: .downstream, stillSelecting: false)
    }

    override func moveWordLeftAndModifySelection(_ sender: Any?) {
        let selectedRange = self.selectedRange()
        guard selectionAffinity == .upstream || selectedRange.length == 0 else {
            // current selection is from left to right: reset selection to the upper bound
            self.selectedRange = NSRange(location: selectedRange.lowerBound, length: 0)
            return
        }
        guard let index = nextWordSelectionIndex(backwards: true) else { return }

        let range = NSRange(location: index, length: selectedRange.upperBound - index)
        self.setSelectedRange(range, affinity: .upstream, stillSelecting: false)
    }

    override func deleteForward(_ sender: Any?) {
        let string = self.string

        guard let selectedRange = Range(self.selectedRange(), in: string),
              let addressBar,
              // Collision of suffix and forward deleting
              !selectedRange.isEmpty || selectedRange.upperBound < addressBar.stringValueWithoutSuffixRange.upperBound else { return }

        super.deleteForward(sender)
    }

    override func deleteBackward(_ sender: Any?) {
        breakUndoCoalescingIfNeeded(for: .delete)
        super.deleteBackward(sender)
    }

    override func deleteWordForward(_ sender: Any?) {
        if selectedRange.length == 0 {
            self.moveWordRightAndModifySelection(sender)
        }

        super.deleteForward(sender)
    }

    override func deleteWordBackward(_ sender: Any?) {
        if selectedRange.length == 0 {
            self.moveWordLeftAndModifySelection(sender)
        }

        super.deleteBackward(sender)
    }

    // MARK: Undo

    var isUndoingOrRedoing: Bool {
        ((undoManager?.isUndoing ?? false) || (undoManager?.isRedoing ?? false)) == false
    }

    override var allowsUndo: Bool {
        get {
            !(addressBar?.isUndoDisabled ?? false) && super.allowsUndo
        }
        set {
            super.allowsUndo = newValue
        }
    }

    override var undoManager: UndoManager? {
        allowsUndo ? super.undoManager : nil
    }

    private enum InputType {
        case letter
        case number
        case separator
        case delete

        init?(_ string: String) {
            guard string.count == 1,
                  let scalar = Unicode.Scalar(string) else { return nil }
            if CharacterSet.letters.contains(scalar) {
                self = .letter
            } else if CharacterSet.decimalDigits.contains(scalar) {
                self = .number
            } else {
                self = .separator
            }
        }
    }
    private var lastInputType: InputType?

    private func breakUndoCoalescingIfNeeded(for inputType: InputType?) {
        defer {
            lastInputType = inputType
        }
        switch (lastInputType, inputType) {
        case (.letter, .letter),
             (.letter, .separator),
             (.separator, .separator),
             (.delete, .delete),
             (.none, .none): // coalesce letters, separators and delete actions
            return
        default:
            break
        }
        breakUndoCoalescing()
    }

}

final class AddressBarTextFieldCell: NSTextFieldCell {
    lazy var customEditor = AddressBarTextEditor()

    override func fieldEditor(for controlView: NSView) -> NSTextView? {
        return customEditor
    }

    override var allowsUndo: Bool {
        get {
            !(customEditor.addressBar?.isUndoDisabled ?? false) && super.allowsUndo
        }
        set {
            super.allowsUndo = newValue
        }
    }

}

extension AddressBarTextField {

    var editor: AddressBarTextEditor? {
        guard let editor = currentEditor() else { return nil }
        guard let addressBarTextEditor = editor as? AddressBarTextEditor else {
            assertionFailure("AddressBarTextField: unexpected kind of editor")
            return nil
        }
        return addressBarTextEditor
    }

}

private extension CharacterSet {
    static let urlWordCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "+_~"))
    static let urlWordBoundCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).inverted
}
