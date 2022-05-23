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
    var firstResponderCancellable: AnyCancellable!
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

        firstResponderCancellable = self.publisher(for: \.firstResponder).sink { [weak self] in
            self?.firstResponderDidChange($0)
        }
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
        guard super.makeFirstResponder(responder) else { return false }

        // The only reliable way to detect NSTextField is the first responder
        // Send it after the first responder has been set on the super class so that window.firstResponder matches correctly
        postFirstResponderNotification(with: responder)
        return true
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
    }

    func firstResponderDidChange(_ firstResponder: NSResponder?) {
        print("firstResponder", firstResponder)

        frv?.removeFromSuperview()
        c = nil
        if let firstResponder = firstResponder as? TabBarCellView {

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
        self.mainViewController?.tabBarViewController.addNewTabButton
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

    override func recalculateKeyViewLoop() {
        // allow Tab through the NSToolbar-owned controls
        mainViewController?.tabBarViewController.view.superview?.setDefaultKeyViewLoop()
        super.recalculateKeyViewLoop()

        mainViewController?.recalculateKeyViewLoop()
    }

    // Disable Key View redirection during nextValidKeyView() search
    @objc(_keyViewRedirectionDisabled)
    func keyViewRedirectionDisabled() -> Bool {
        true
    }

}

extension Notification.Name {
    static let firstResponder = Notification.Name("firstResponder")
}
