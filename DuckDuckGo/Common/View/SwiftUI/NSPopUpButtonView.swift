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

struct NSPopUpButtonView<ItemType>: NSViewRepresentable where ItemType: Equatable {

    typealias NSViewType = NSPopUpButton

    @Binding var selection: ItemType

    var viewCreator: () -> NSPopUpButton

    func makeNSView(context: NSViewRepresentableContext<NSPopUpButtonView>) -> NSPopUpButton {
        let newPopupButton = viewCreator()
        setPopUpFromSelection(newPopupButton, selection: selection)

        newPopupButton.target = context.coordinator
        newPopupButton.action = #selector(Coordinator.dropdownItemSelected(_:))

        return newPopupButton
    }

    func updateNSView(_ nsView: NSPopUpButton, context: NSViewRepresentableContext<NSPopUpButtonView>) {
        setPopUpFromSelection(nsView, selection: selection)
    }

    func setPopUpFromSelection(_ button: NSPopUpButton, selection: ItemType) {
        let itemsList = button.itemArray
        let matchedMenuItem = itemsList.filter { ($0.representedObject as? ItemType) == selection }.first

        if matchedMenuItem != nil {
            button.select(matchedMenuItem)
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    final class Coordinator: NSObject {
        var parent: NSPopUpButtonView!

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
            parent.selection = selectedItem.representedObject as! ItemType
        }
    }
}
