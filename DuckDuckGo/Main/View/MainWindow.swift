//
//  MainWindow.swift
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

final class MainWindow: NSWindow {

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }

    var mainViewController: MainViewController? {
        guard let mainViewController = contentViewController as? MainViewController else {
            assertionFailure("Unexpected View Controller type")
            return nil
        }
        return mainViewController
    }

    init(frame: NSRect) {
        super.init(contentRect: frame,
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: true)

        setupWindow()
    }

    private func setupWindow() {
        allowsToolTipsWhenApplicationIsInactive = false
        autorecalculatesKeyViewLoop = true
        isReleasedWhenClosed = false
        animationBehavior = .documentWindow
        hasShadow = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        // the window will be draggable using custom drag areas defined by WindowDraggingView
        isMovable = false
    }

    // MARK: - First Responder Notification

    private var addedOrRemovedChildWindow: NSWindow?

    override func removeChildWindow(_ childWin: NSWindow) {
        self.addedOrRemovedChildWindow = childWin
        super.removeChildWindow(childWin)
        self.addedOrRemovedChildWindow = nil
    }

    override func addChildWindow(_ childWin: NSWindow, ordered place: NSWindow.OrderingMode) {
        self.addedOrRemovedChildWindow = childWin
        super.addChildWindow(childWin, ordered: place)
        self.addedOrRemovedChildWindow = nil
    }

    var displayedPopovers: [NSPopover] {
        self.childWindows?.compactMap { window in
            guard window !== addedOrRemovedChildWindow else { return nil }
            return window.contentViewController?.nextResponder as? NSPopover
        } ?? []
    }

    override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        func popoverShouldClose(_ popover: NSPopover) -> Bool {
            if responder == nil {
                return false
            } else if let responder = responder as? NSView,
               let popoverView = popover.contentViewController?.view,
               responder.isDescendant(of: popoverView) {
                return false
            } else if popover.contentViewController?.view.window === responder {
                return false
            }

            return popover.delegate?.popoverShouldClose?(popover) == true
                || [.transient, .semitransient].contains(popover.behavior)
        }
        for popover in displayedPopovers where popoverShouldClose(popover) {
            popover.close()
        }

        guard self.firstResponder !== responder else { return true }
        // The only reliable way to detect NSTextField is the first responder
        defer {
            // Send it after the first responder has been set on the super class so that window.firstResponder matches correctly
            postFirstResponderNotification(with: responder)
        }
        
        return super.makeFirstResponder(responder)
    }

    override func becomeMain() {
        super.becomeMain()

        postFirstResponderNotification(with: firstResponder)
    }

    override func endEditing(for object: Any?) {
        if case .leftMouseUp = NSApp.currentEvent?.type,
           object is AddressBarTextEditor {
            // prevent deactivation of Address Bar on Toolbar click
            return
        }

        super.endEditing(for: object)
    }

    final class ClipView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
    var cont: NSView!
    var frv: NSView?
    var c: Any?
    private func postFirstResponderNotification(with firstResponder: NSResponder?) {
        NotificationCenter.default.post(name: .firstResponder, object: firstResponder)
        // TODO: Endless loop if right-click Username field and then Tab // swiftlint:disable:this todo
        print("firstResponder", firstResponder)

        frv?.removeFromSuperview()
        c = nil
        if let firstResponder = firstResponder as? TabBarView {

            let cframe = firstResponder.enclosingScrollView?.superview?
                .convert(firstResponder.enclosingScrollView!.frame, to: self.contentView!.superview!)
                .insetBy(dx: -2, dy: -6)
            if let cframe = cframe {
                if cont == nil {
                    let c = ClipView(frame: cframe)
                    c.autoresizingMask = [.width, .minYMargin]
                    c.wantsLayer = true
                    c.layer!.cornerRadius = 12.0
                    cont = c

                    self.contentView!.superview!.addSubview(c)
                }
                cont.frame = cframe
            }

            let shadow = ShadowView()
            shadow.stroke = 2
            frv = shadow

            let frame = firstResponder.bounds
            firstResponder.enclosingScrollView?.postsBoundsChangedNotifications = true
            c = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification,
                                                       object: firstResponder.enclosingScrollView?.contentView,
                                                       queue: nil) { [weak shadow, cont] _ in

                shadow?.frame = firstResponder.convert(frame, to: cont) // self.contentView!.superview!)
            }
            shadow.frame = firstResponder.convert(frame, to: cont) // self.contentView!.superview!)

            shadow.shadowColor = NSColor.controlAccentColor
            shadow.shadowRadius = 0
            shadow.cornerRadius = 6
            shadow.shadowOpacity = 1.0
            shadow.shouldHideOnLostFocus = true
//            frv?.strokedBackgroundColor = .clear
//            frv?.unstrokedBackgroundColor = .clear
//            self.contentView!.superview!.addSubview(frv!)
            cont.addSubview(shadow)

//            DispatchQueue.main.async {
//                self.frv!.updateView(stroke: true)
//            }

        }
    }
    @objc func handleEvent(_ event: NSEvent) -> Bool {
print(event)
        return true
    }

    var newTabButton: NSButton? {
        self.mainViewController?.tabBarViewController.addButton ??
            mainViewController?.tabBarViewController.plusButton
    }

    override func accessibilityChildren() -> [Any]? {
        var children = super.accessibilityChildren() as? [NSObject] ?? []
        let newTabButton = self.newTabButton
        if let newTabIdx = children.firstIndex(where: { $0 === newTabButton?.cell }) {
            children.remove(at: newTabIdx)
        }
        return children
    }
    
    // Handle Keyboard toggle Toolbar focus (Ctrl+F5)
    @objc(_handleFocusToolbarHotKey:)
    func handleFocusToolbarHotKey(_ event: Any?) {
        guard displayedPopovers.isEmpty else { return }
        mainViewController?.toggleToolbarFocus()
    }

    // Esc
    override func cancelOperation(_ sender: Any?) {
        guard !(firstResponder is WebView) else {
            super.cancelOperation(sender)
            return
        }
        self.mainViewController?.adjustFirstResponder()
    }

    final class TabBarViewItemProxy: NSView {
        weak var collectionView: TabBarCollectionView?
        let index: Int
        let position: Position

        enum Position {
            case first
            case second
            case beforeLast
            case last
        }

        init(collectionView: TabBarCollectionView, index: Int, position: Position) {
            self.collectionView = collectionView
            self.index = index
            self.position = position
            let frame = [.first, .second].contains(position)
                ? NSRect(x: 0, y: 0, width: 1, height: collectionView.frame.height)
                : NSRect(x: collectionView.enclosingScrollView!.frame.width - 1, y: 0, width: 1, height: collectionView.frame.height)
            super.init(frame: frame)

            collectionView.enclosingScrollView?.addSubview(self)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var acceptsFirstResponder: Bool {
            NSApp.isFullKeyboardAccessEnabled && self.isVisible
        }

        override var canBecomeKeyView: Bool {
            NSApp.isFullKeyboardAccessEnabled && self.isVisible
        }

        override func becomeFirstResponder() -> Bool {
            guard let collectionView = collectionView else { return false }
            self.removeFromSuperview()

            collectionView.scroll(to: index) { [index, position] _ in
                guard let item = collectionView.item(at: IndexPath(item: index, section: 0))
                else { return }

                switch position {
                // Navigating backward to a Tab's button
                case .second, .last:
                    guard let btn = item.view.subviews.filter({ ($0 as? NSButton)?.canBecomeKeyView == true }).last else { fallthrough }
                    btn.makeMeFirstResponder()
                // Navigating forward to the Tab
                case .first, .beforeLast:
                    item.view.makeMeFirstResponder()
                }
            }
            return false
        }
    }

    override func recalculateKeyViewLoop() {
        mainViewController?.tabBarViewController.view.superview?.setDefaultKeyViewLoop()
        super.recalculateKeyViewLoop()

//        mainViewController?.navigationBarViewController.optionsButton.nextKeyView =
//            mainViewController?.tabBarViewController.collectionView.subviews.first
        // TODO: Need to iterate through collectionView.itemAtIndexPath because not all views are created // swiftlint:disable:this todo
        let cv = mainViewController!.tabBarViewController.collectionView!
        let visibleIndexPaths = cv.indexPathsForVisibleItems().sorted()
        var views = [NSView]()
        if let min = visibleIndexPaths.first,
           min.item > 0 {
            views.append(TabBarViewItemProxy(collectionView: cv, index: 0, position: .first))
            views.append(TabBarViewItemProxy(collectionView: cv, index: min.item - 1, position: .second))
        }
        views.append(contentsOf: visibleIndexPaths.compactMap { cv.item(at: $0)?.view })    
        if let max = visibleIndexPaths.last,
           max.item < cv.numberOfItems(inSection: 0) - 1 {
            views.append(TabBarViewItemProxy(collectionView: cv, index: max.item + 1, position: .beforeLast))
            views.append(TabBarViewItemProxy(collectionView: cv, index: cv.numberOfItems(inSection: 0) - 1, position: .last))
        }

        for (idx, view) in views.enumerated() {
            if idx == 0 {
                mainViewController?.navigationBarViewController.optionsButton.nextKeyView = view
            }
            let btns = view.subviews.filter { $0 is NSButton }
            if btns.isEmpty {
                view.nextKeyView = views[safe: idx + 1] ?? self.newTabButton
            } else {
                view.nextKeyView = btns[0]
                for btnIdx in btns.indices {
                    btns[btnIdx].nextKeyView = btns[safe: btnIdx + 1] ?? views[safe: idx + 1] ?? self.newTabButton
                }
            }

        }
        self.newTabButton?.nextKeyView = mainViewController?.tabBarViewController.fireButton

//        let btns: [NSView] = [
//            self.mainViewController!.tabBarViewController.fireButton,
//            self.mainViewController!.navigationBarViewController.goBackButton,
//            self.mainViewController!.navigationBarViewController.goForwardButton,
//            self.mainViewController!.navigationBarViewController.refreshButton,
//            self.mainViewController!.navigationBarViewController.addressBarViewController!.addressBarButtonsViewController!.imageButton,
//            self.mainViewController!.navigationBarViewController.addressBarViewController!.addressBarTextField
//        ]
//
//        for (idx, btn) in btns.enumerated() {
//            if idx == btns.count - 1 {
//                btn.nextKeyView = self.mainViewController!.navigationBarViewController.optionsButton
//            } else {

//                btn.nextKeyView = btns[idx + 1]
//            }
//        }

        mainViewController?.tabBarViewController.fireButton.nextKeyView = self.mainViewController?.navigationBarViewController.goBackButton
//
//        self.mainViewController?.navigationBarViewController.goBackButton.nextKeyView = self.mainViewController?.navigationBarViewController.goForwardButton
//        self.mainViewController?.navigationBarViewController.goForwardButton.nextKeyView = self.mainViewController?.navigationBarViewController.refreshButton
//        self.mainViewController?.navigationBarViewController.refreshButton.nextKeyView = self.mainViewController?.navigationBarViewController.addressBarViewController?.addressBarTextField

//        mainViewController?.webContainerView.nextKeyView = mainViewController?.tabBarViewController.view
//        mainViewController?.tabBarViewController.view.nextKeyView = mainViewController?.navigationBarViewController.view.nextKeyView
    }

    @objc(_keyViewRedirectionDisabled)
    func keyViewRedirectionDisabled() -> Bool {
        true
    }

}

extension Notification.Name {
    static let firstResponder = Notification.Name("firstResponder")
}
