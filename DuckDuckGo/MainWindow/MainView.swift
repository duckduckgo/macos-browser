//
//  MainView.swift
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
import WebKit

final class MainView: NSView {
    let tabBarContainerView = NSView()
    let navigationBarContainerView = NSView()
    let webContainerView = NSView()
    let findInPageContainerView = NSView().hidden()
    let bookmarksBarContainerView = NSView()
    let bannerContainerView = NSView()
    let fireContainerView = NSView()
    let divider = ColorView(frame: .zero, backgroundColor: .separatorColor)

    private(set) var navigationBarTopConstraint: NSLayoutConstraint!
    private(set) var bookmarksBarHeightConstraint: NSLayoutConstraint!
    private(set) var webContainerTopConstraint: NSLayoutConstraint!
    private(set) var webContainerTopConstraintToNavigation: NSLayoutConstraint!
    private(set) var tabBarHeightConstraint: NSLayoutConstraint!
    private(set) var bannerHeightConstraint: NSLayoutConstraint!

    @Published var isMouseAboveWebView: Bool = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        for subview in [
            tabBarContainerView,
            divider,
            bookmarksBarContainerView,
            navigationBarContainerView,
            webContainerView,
            bannerContainerView,
            findInPageContainerView,
            fireContainerView
        ] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            addSubview(subview)
        }

        addConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addConstraints() {
        bookmarksBarHeightConstraint = bookmarksBarContainerView.heightAnchor.constraint(equalToConstant: 34)
        tabBarHeightConstraint = tabBarContainerView.heightAnchor.constraint(equalToConstant: 38)
        navigationBarTopConstraint = navigationBarContainerView.topAnchor.constraint(equalTo: topAnchor, constant: 38)
        webContainerTopConstraint = webContainerView.topAnchor.constraint(equalTo: bannerContainerView.bottomAnchor)
        webContainerTopConstraintToNavigation = webContainerView.topAnchor.constraint(equalTo: navigationBarContainerView.bottomAnchor)

        webContainerTopConstraint.priority = .defaultHigh
        webContainerTopConstraintToNavigation.priority = .defaultLow

        bannerHeightConstraint = bannerContainerView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            tabBarContainerView.topAnchor.constraint(equalTo: topAnchor),
            tabBarContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tabBarContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tabBarHeightConstraint,

            divider.topAnchor.constraint(equalTo: navigationBarContainerView.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),

            bookmarksBarContainerView.topAnchor.constraint(equalTo: divider.bottomAnchor),
            bookmarksBarContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bookmarksBarContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bookmarksBarHeightConstraint,

            navigationBarTopConstraint,
            navigationBarContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            navigationBarContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),

            bannerHeightConstraint,
            bannerContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bannerContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bannerContainerView.topAnchor.constraint(equalTo: bookmarksBarContainerView.bottomAnchor),

            webContainerTopConstraint,
            webContainerTopConstraintToNavigation,
            webContainerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            webContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webContainerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 512),
            webContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 178),

            findInPageContainerView.topAnchor.constraint(equalTo: bookmarksBarContainerView.bottomAnchor, constant: -4),
            findInPageContainerView.topAnchor.constraint(equalTo: navigationBarContainerView.bottomAnchor, constant: -4).priority(900),
            findInPageContainerView.centerXAnchor.constraint(equalTo: navigationBarContainerView.centerXAnchor),
            findInPageContainerView.widthAnchor.constraint(equalToConstant: 400),
            findInPageContainerView.heightAnchor.constraint(equalToConstant: 40),

            fireContainerView.topAnchor.constraint(equalTo: topAnchor),
            fireContainerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            fireContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            fireContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    private typealias CFWebServicesCopyProviderInfoType = @convention(c) (CFString, UnsafeRawPointer?) -> NSDictionary?

    // PDF Plugin context menu
    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        setupSearchContextMenuItem(menu: menu)
        setupSaveAsAndPrintMenuItems(menu: menu, with: event)
        super.willOpenMenu(menu, with: event)
    }

    private func setupSearchContextMenuItem(menu: NSMenu) {
        // Intercept [_NSServiceEntry invokeWithPasteboard:] to catch selected PDF text "Search with %@" menu item
        PDFSearchTextMenuItemHandler.swizzleInvokeWithPasteboardOnce()

        // Get system default Search Engine name
        guard let CFWebServicesCopyProviderInfo: CFWebServicesCopyProviderInfoType? = dynamicSymbol(named: "_CFWebServicesCopyProviderInfo"),
              let info = CFWebServicesCopyProviderInfo?("NSWebServicesProviderWebSearch" as CFString, nil),
              let providerDisplayName = info["NSDefaultDisplayName"] as? String,
              providerDisplayName != "DuckDuckGo"
        else { return }

        // Find the "Search with %@" item and replace %@ with DuckDuckGo
        for item in menu.items {
            guard !item.isSeparatorItem else { break }
            if item.title.contains(providerDisplayName) {
                item.title = item.title.replacingOccurrences(of: providerDisplayName, with: "DuckDuckGo")
                break
            }
        }
    }

    private func setupSaveAsAndPrintMenuItems(menu: NSMenu, with event: NSEvent) {
        guard let window else { return }

        // try to find PDF HUD view at the right-click location (it might be a frame click)
        let hudView: WKPDFHUDViewWrapper? = {
            for point in [event.locationInWindow, window.mouseLocationOutsideOfEventStream] {
                let locationInView = convert(point, from: nil)
                guard let view = self.hitTest(locationInView) else { continue }

                if let hudView = WKPDFHUDViewWrapper(view: view) {
                    return hudView
                } else if let webView = view as? WKWebView,
                          let hudView = webView.hudView(at: webView.convert(locationInView, from: self)) {
                    return hudView
                }
            }
            return (self.hitTest(bounds.center) as? WKWebView)?.hudView()
        }()
        assert(hudView != nil)

        // insert Save As… and Print… items after `Open with Preview`
        // 1. find `Copy`
        let idxAfterCopy = menu.indexOfItem(withTitle: UserText.copy) + /* will become 0 if no copy (-1 + 1) */ 1
        let insertionIdx: Int
        if idxAfterCopy > 0 {
            // 2. find separator below `Copy`
            let separatorIdx = (idxAfterCopy..<menu.items.endIndex).first(where: { menu.items[$0].isSeparatorItem }) ?? idxAfterCopy //  separator
            // 3. descend 2 items down: the separator, `Open with Preview`
            insertionIdx = min(separatorIdx + 2, menu.items.count /* just in case… */)
        } else {
            insertionIdx = min(1, menu.items.count /* just in case… */)
        }

        menu.insertItem(NSMenuItem(title: UserText.mainMenuFileSaveAs, action: #selector(MainViewController.saveAs), representedObject: hudView),
                        at: insertionIdx)
        menu.insertItem(NSMenuItem(title: UserText.printMenuItem, action: #selector(MainViewController.printWebView), representedObject: hudView),
                        at: insertionIdx)
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ draggingInfo: NSDraggingInfo) -> NSDragOperation {
        return (nextResponder as? NSDraggingDestination)?.draggingEntered?(draggingInfo) ?? .none
    }

    override func draggingUpdated(_ draggingInfo: NSDraggingInfo) -> NSDragOperation {
        return (nextResponder as? NSDraggingDestination)?.draggingUpdated?(draggingInfo) ?? .none
    }

    override func performDragOperation(_ draggingInfo: NSDraggingInfo) -> Bool {
        return (nextResponder as? NSDraggingDestination)?.performDragOperation?(draggingInfo) ?? false
    }

    // MARK: - Mouse Tracking

    func setMouseAboveWebViewTrackingAreaEnabled(_ isEnabled: Bool) {
        if isEnabled {
            let trackingArea = makeMouseAboveViewTrackingArea()
            addTrackingArea(trackingArea)
            mouseAboveWebViewTrackingArea = trackingArea
        } else if let mouseAboveWebViewTrackingArea {
            removeTrackingArea(mouseAboveWebViewTrackingArea)
            self.mouseAboveWebViewTrackingArea = nil
            isMouseAboveWebView = false
        }
    }

    override func updateTrackingAreas() {
        if let mouseAboveWebViewTrackingArea {
            removeTrackingArea(mouseAboveWebViewTrackingArea)
            isMouseAboveWebView = false
            let trackingArea = makeMouseAboveViewTrackingArea()
            self.mouseAboveWebViewTrackingArea = trackingArea
            addTrackingArea(trackingArea)
        }
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        if event.type == .mouseEntered, let mouseAboveWebViewTrackingArea, event.trackingArea == mouseAboveWebViewTrackingArea {
            isMouseAboveWebView = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        if event.type == .mouseExited, let mouseAboveWebViewTrackingArea, event.trackingArea == mouseAboveWebViewTrackingArea {
            isMouseAboveWebView = false
        }
    }

    private func makeMouseAboveViewTrackingArea() -> NSTrackingArea {
        var bounds = bounds
        bounds.size.height -= webContainerView.bounds.maxY
        bounds.origin.y += webContainerView.bounds.maxY
        return NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseEnteredAndExited], owner: self, userInfo: nil)
    }

    private var mouseAboveWebViewTrackingArea: NSTrackingArea?

}
