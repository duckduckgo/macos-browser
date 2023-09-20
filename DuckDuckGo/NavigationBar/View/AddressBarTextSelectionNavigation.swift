//
//  AddressBarTextSelectionNavigation.swift
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
import Foundation

@available(macOS 12.0, *)
final class AddressBarTextSelectionNavigation: NSTextSelectionNavigation {
    private weak var dataSource: NSTextLayoutManager?

    override init(dataSource: NSTextSelectionDataSource) {
        self.dataSource = dataSource as? NSTextLayoutManager
        super.init(dataSource: dataSource)
    }

    // to be updated on macOS 11 drop: move logics from AddressBarTextEditor.selectionRange(forProposedRange:granularity:)
    override func textSelection(for granularity: NSTextSelection.Granularity, enclosing selection: NSTextSelection) -> NSTextSelection {
        guard let range = selection.textRanges.first else { return selection }
        guard let dataSource, let textView = dataSource.textContainer?.textView as? AddressBarTextEditor else { return selection }

        let start = dataSource.documentRange.location
        let location = dataSource.offset(from: start, to: range.location)
        let length = dataSource.offset(from: range.location, to: range.endLocation)
        let newRange = textView.selectionRange(forProposedRange: NSRange(location: location, length: length), granularity: NSSelectionGranularity(granularity))

        guard let newLocation = dataSource.location(start, offsetBy: newRange.location),
              let newEnd = dataSource.location(newLocation, offsetBy: newRange.length),
              let selectionRange = NSTextRange(location: newLocation, end: newEnd) else { return selection }

        return NSTextSelection(range: selectionRange, affinity: selection.affinity, granularity: granularity)
    }

    override func textSelections(interactingAt point: CGPoint, inContainerAt containerLocation: NSTextLocation, anchors: [NSTextSelection], modifiers: NSTextSelectionNavigation.Modifier, selecting: Bool, bounds: CGRect) -> [NSTextSelection] {

        let selections = super.textSelections(interactingAt: point, inContainerAt: containerLocation, anchors: anchors, modifiers: modifiers, selecting: selecting, bounds: bounds)
        guard modifiers == .extend,
              let proposedSelection = selections.first,
              let anchor = anchors.first else { return selections }

        let textSelection = textSelection(for: anchor.granularity, enclosing: proposedSelection)
        guard let textSelectionRange = textSelection.textRanges.first,
              let anchorRange = anchor.textRanges.first else { return selections }

        let range = textSelectionRange.union(anchorRange)
        let extendedSelection = NSTextSelection(range: range, affinity: anchor.affinity, granularity: anchor.granularity)

        return [extendedSelection]
    }

}

@available(macOS 12.0, *)
extension NSSelectionGranularity {

    init(_ textSelectionGranularity: NSTextSelection.Granularity) {
        switch textSelectionGranularity {
        case .character:
            self = .selectByCharacter
        case .word:
            self = .selectByWord
        default:
            self = .selectByParagraph
        }
    }

}
