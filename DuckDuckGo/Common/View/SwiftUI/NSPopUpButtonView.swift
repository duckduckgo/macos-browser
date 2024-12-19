//
//  NSPopUpButtonView.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import SwiftUI
import Utilities

struct PopupButtonItem<SelectionValue: Equatable>: Equatable {

    var icon: NSImage?
    var title: String
    var keyEquivalent: String = ""
    var indentation: Int = 0
    var selectionValue: SelectionValue?

    static func separator() -> PopupButtonItem { PopupButtonItem(title: "-") }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.title == rhs.title && lhs.keyEquivalent == rhs.keyEquivalent && lhs.indentation == rhs.indentation && lhs.selectionValue == rhs.selectionValue && lhs.icon?.size == rhs.icon?.size && lhs.icon?.tiffRepresentation == rhs.icon?.tiffRepresentation
    }
}

struct NSPopUpButtonView<SelectionValue: Equatable>: NSViewRepresentable {

    typealias NSViewType = NSPopUpButton

    @Binding var selection: SelectionValue

    let viewCreator: () -> NSPopUpButton
    let content: (() -> [PopupButtonItem<SelectionValue>])?

    init(selection: Binding<SelectionValue>, viewCreator: @escaping () -> NSPopUpButton) {
        self._selection = selection
        self.viewCreator = viewCreator
        self.content = nil
    }

    init(selection: Binding<SelectionValue>, viewCreator: @escaping () -> NSPopUpButton, @ArrayBuilder<PopupButtonItem<SelectionValue>> content: @escaping () -> [PopupButtonItem<SelectionValue>]) {
        self._selection = selection
        self.viewCreator = viewCreator
        self.content = content
    }

    func makeNSView(context: NSViewRepresentableContext<NSPopUpButtonView>) -> NSPopUpButton {
        let newPopupButton = viewCreator()
        setPopUpFromSelection(newPopupButton, selection: selection)

        newPopupButton.target = context.coordinator
        newPopupButton.action = #selector(Coordinator.dropdownItemSelected(_:))

        return newPopupButton
    }

    func updateNSView(_ button: NSPopUpButton, context: NSViewRepresentableContext<NSPopUpButtonView>) {
        if let content {
            let newContent = content()
            let diff = newContent.difference(from: context.coordinator.content) { $0 == $1 }
            defer {
                context.coordinator.content = newContent
            }
            for change in diff {
                switch change {
                case .remove(offset: let offset, element: _, associatedWith: _):
                    button.removeItem(at: offset)
                case .insert(offset: let offset, element: let element, associatedWith: _):
                    let menuItem: NSMenuItem
                    if element == .separator() {
                        menuItem = .separator()

                    } else {
                        menuItem = NSMenuItem(title: element.title, representedObject: element.selectionValue)
                        menuItem.image = element.icon
                        menuItem.keyEquivalent = element.keyEquivalent
                        menuItem.indentationLevel = element.indentation
                    }
                    button.menu?.insertItem(menuItem, at: offset)
                }
            }
        }

        setPopUpFromSelection(button, selection: selection)
    }

    func setPopUpFromSelection(_ button: NSPopUpButton, selection: SelectionValue) {
        let itemsList = button.itemArray
        let matchedMenuItem = itemsList.first(where: { ($0.representedObject as? SelectionValue) == selection })

        if matchedMenuItem != nil {
            button.select(matchedMenuItem)
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    final class Coordinator: NSObject {
        var parent: NSPopUpButtonView!
        var content: [PopupButtonItem<SelectionValue>] = []

        init(_ parent: NSPopUpButtonView) {
            super.init()
            self.parent = parent
        }

        @objc func dropdownItemSelected(_ sender: NSPopUpButton) {
            guard let selectedItem = sender.selectedItem else {
                assertionFailure()
                return
            }
            // swiftlint:disable:next force_cast
            parent.selection = selectedItem.representedObject as! SelectionValue
        }
    }
}
