//
//  WebExtensionEventsListener.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

@available(macOS 14.4, *)
protocol WebExtensionEventsListening {

    var controller: _WKWebExtensionController? { get set }

    func didOpenWindow(_ window: _WKWebExtensionWindow)
    func didCloseWindow(_ window: _WKWebExtensionWindow)
    func didFocusWindow(_ window: _WKWebExtensionWindow)
    func didOpenTab(_ tab: _WKWebExtensionTab)
    func didCloseTab(_ tab: _WKWebExtensionTab, windowIsClosing: Bool)
    func didActivateTab(_ tab: _WKWebExtensionTab, previousActiveTab: _WKWebExtensionTab?)
    func didSelectTabs(_ tabs: [_WKWebExtensionTab])
    func didDeselectTabs(_ tabs: [_WKWebExtensionTab])
    func didMoveTab(_ tab: _WKWebExtensionTab, from oldIndex: Int, in oldWindow: _WKWebExtensionWindow)
    func didReplaceTab(_ oldTab: _WKWebExtensionTab, with tab: _WKWebExtensionTab)
    func didChangeTabProperties(_ properties: _WKWebExtensionTabChangedProperties, for tab: _WKWebExtensionTab)
}

@available(macOS 14.4, *)
final class WebExtensionEventsListener: WebExtensionEventsListening {

    weak var controller: _WKWebExtensionController?

    func didOpenWindow(_ window: _WKWebExtensionWindow) {
        controller?.didOpen(window)
    }

    func didCloseWindow(_ window: _WKWebExtensionWindow) {
        controller?.didClose(window)
    }

    func didFocusWindow(_ window: _WKWebExtensionWindow) {
        controller?.didFocus(window)
    }

    func didOpenTab(_ tab: _WKWebExtensionTab) {
        controller?.didOpen(tab)
    }

    func didCloseTab(_ tab: _WKWebExtensionTab, windowIsClosing: Bool) {
        controller?.didClose(tab, windowIsClosing: windowIsClosing)
    }

    func didActivateTab(_ tab: _WKWebExtensionTab, previousActiveTab: _WKWebExtensionTab?) {
        controller?.didActivate(tab, previousActiveTab: previousActiveTab)
    }

    func didSelectTabs(_ tabs: [_WKWebExtensionTab]) {
        let set = NSSet(array: tabs) as Set
        controller?.didSelect(set)
    }

    func didDeselectTabs(_ tabs: [_WKWebExtensionTab]) {
        let set = NSSet(array: tabs) as Set
        controller?.didDeselect(set)
    }

    func didMoveTab(_ tab: _WKWebExtensionTab, from oldIndex: Int, in oldWindow: _WKWebExtensionWindow) {
        controller?.didMoveTab(tab, from: UInt(oldIndex), in: oldWindow)
    }

    func didReplaceTab(_ oldTab: _WKWebExtensionTab, with tab: _WKWebExtensionTab) {
        controller?.didReplaceTab(oldTab, with: tab)
    }

    func didChangeTabProperties(_ properties: _WKWebExtensionTabChangedProperties, for tab: _WKWebExtensionTab) {
        controller?.didChangeTabProperties(properties, for: tab)
    }

}
