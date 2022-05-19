//
//  ViewExtensions.swift
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

import SwiftUI

// https://swiftuirecipes.com/blog/how-to-hide-a-swiftui-view-visible-invisible-gone
enum ViewVisibility: CaseIterable {

    case visible, // view is fully visible
         invisible, // view is hidden but takes up space
         gone // view is fully removed from the view hierarchy
    
}

extension View {

    // https://swiftuirecipes.com/blog/how-to-hide-a-swiftui-view-visible-invisible-gone
    @ViewBuilder func visibility(_ visibility: ViewVisibility) -> some View {
        if visibility != .gone {
            if visibility == .visible {
                self
            } else {
                hidden()
            }
        }
    }

    // https://stackoverflow.com/questions/67242086/swiftui-how-can-i-get-the-frame-of-a-view-in-a-dynamic-list-or-lazyvstack
    func onFrameUpdated(_ frameUpdated: @escaping (CGRect) -> Void) -> some View {
        self.background(GeometryReader { geometryReader in
            // swiftlint:disable:next redundant_discardable_let
            let _ = frameUpdated(geometryReader.frame(in: .global))
            Color.clear
        })
    }

    func link(onHoverChanged: ((Bool) -> Void)? = nil, clicked: @escaping () -> Void) -> some View {
        self.onHover { over in
            onHoverChanged?(over)
        }.onTapGesture {
            clicked()
        }
    }

    @ViewBuilder
    func focusable(_ focusable: Bool = true,
                   onClick: Bool = false,
                   focusRing: Bool = true,
                   tag: Int = 0,
                   onFocus: ((Bool) -> Void)? = nil,
                   onViewFocused: ((FocusView) -> Void)? = nil,
                   onAppear: ((FocusView) -> Void)? = nil,
                   action: (() -> Void)? = nil,
                   menu: (() -> NSMenu)? = nil,
                   onCopy: (() -> Void)? = nil,
                   keyDown: ((NSEvent) -> NSEvent?)? = nil) -> some View {
        if focusable {
            self.overlay(FocusSwiftUIView(onClick: onClick,
                                          focusRing: focusRing,
                                          tag: tag,
                                          onFocus: onFocus,
                                          onViewFocused: onViewFocused,
                                          onAppear: onAppear,
                                          action: action,
                                          menu: menu,
                                          onCopy: onCopy,
                                          keyDown: keyDown),
                         alignment: .leading)
        } else {
            self
        }
    }

    @ViewBuilder
    func onDefaultAction(_ action: (() -> Void)?) -> some View {
        self.onCommand(#selector(NSCell.performClick(_:)), perform: action)
    }

    @ViewBuilder
    func textSelectableIfAvailable() -> some View {
        if #available(macOS 12.0, *) {
            self.textSelection(.enabled)
        } else {
            self
        }
    }

    @ViewBuilder
    func keyboardShortcutIfAvailable(_ key: Character, modifiers: EventModifiers = []) -> some View {
        if #available(macOS 11.0, *) {
            keyboardShortcut(.init(key), modifiers: modifiers)
        } else {
            self
        }
    }

    @ViewBuilder func tooltip(_ message: String) -> some View {
        if #available(macOS 11.0, *) {
            self.help(message)
        } else {
            self
        }
    }

}

extension Text {

    func optionalUnderline(_ underline: Bool) -> Text {
        if underline {
            return self.underline()
        } else {
            return self
        }
    }

}

extension Character {

    static let escape = Character("\u{001B}")
    static let `return` = Character("\u{000D}")

}
