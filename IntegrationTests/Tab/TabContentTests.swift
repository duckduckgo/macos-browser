//
//  TabContentTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import Combine
import Common
import XCTest
@testable import DuckDuckGo_Privacy_Browser

@available(macOS 12.0, *)
@MainActor
class TabContentTests: XCTestCase {

    var window: NSWindow!

    var mainViewController: MainViewController {
        (window.contentViewController as! MainViewController)
    }

    var tabViewModel: TabViewModel {
        mainViewController.browserTabViewController.tabViewModel!
    }

    @MainActor
    override func setUp() async throws {
    }

    @MainActor
    override func tearDown() async throws {
        window?.close()
        window = nil
        NSView.swizzleWillOpenMenu(with: nil)
    }

    // MARK: - Tests

    @MainActor
    func testWhenPDFContextMenuPrintChosen_printDialogOpens() async throws {
        let pdfUrl = Bundle(for: Self.self).url(forResource: "empty", withExtension: "pdf")!
        // open Tab with PDF
        let tab = Tab(content: .url(pdfUrl, credential: nil, source: .userEntered("")))
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        let eNewtabPageLoaded = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        try await eNewtabPageLoaded.value

        let point = tab.webView.convert(tab.webView.bounds.center, to: nil)

        NSApp.activate(ignoringOtherApps: true)
        let mouseDown = NSEvent.mouseEvent(with: .rightMouseDown,
                                           location: point,
                                           modifierFlags: [],
                                           timestamp: CACurrentMediaTime(),
                                           windowNumber: window.windowNumber,
                                           context: nil,
                                           eventNumber: -22966,
                                           clickCount: 1,
                                           pressure: 1)!

        // wait for context menu to appear
        let eMenuShown = expectation(description: "menu shown")
        var menuItems = [NSMenuItem]()
        NSView.swizzleWillOpenMenu { menu, event in
            menuItems = menu.items
            menu.removeAllItems()
            eMenuShown.fulfill()
        }

        // right-click
        window.sendEvent(mouseDown)
        await fulfillment(of: [eMenuShown])

        // find Print, Save As
        guard let printMenuItem = menuItems.first(where: { $0.title == UserText.printMenuItem }) else {
            XCTFail("No print menu item")
            return
        }
        let saveAsMenuItem = menuItems.first(where: { $0.title == UserText.mainMenuFileSaveAs })
        XCTAssertNotNil(saveAsMenuItem)

        // wait for print dialog to appear
        let ePrintDialogShown = expectation(description: "Print dialog shown")
        let getPrintDialog = Task {
            while true {
                if let sheet = self.window.sheets.first {
                    ePrintDialogShown.fulfill()
                    return sheet
                }
                try await Task.sleep(interval: 0.01)
            }
        }

        // Click Print…
        printMenuItem.accessibilityPerformPress()
        if case .timedOut = await XCTWaiter(delegate: self).fulfillment(of: [ePrintDialogShown], timeout: 5) {
            getPrintDialog.cancel()
        }
        let printDialog = try await getPrintDialog.value

        XCTAssertEqual(printDialog.title, UserText.printMenuItem.dropping(suffix: "…"))
    }

    @MainActor
    func disabled_testWhenPDFContextMenuSaveAsChosen_saveDialogOpens() async throws {
        let pdfUrl = Bundle(for: Self.self).url(forResource: "empty", withExtension: "pdf")!
        // open Tab with PDF
        let tab = Tab(content: .url(pdfUrl, credential: nil, source: .userEntered("")))
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        let eNewtabPageLoaded = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        try await eNewtabPageLoaded.value

        let point = tab.webView.convert(tab.webView.bounds.center, to: nil)

        NSApp.activate(ignoringOtherApps: true)
        let mouseDown = NSEvent.mouseEvent(with: .rightMouseDown,
                                           location: point,
                                           modifierFlags: [],
                                           timestamp: CACurrentMediaTime(),
                                           windowNumber: window.windowNumber,
                                           context: nil,
                                           eventNumber: -22966,
                                           clickCount: 1,
                                           pressure: 1)!

        // wait for context menu to appear
        let menuWindowPromise = Timer.publish(every: 0.01, on: .main, in: .common).autoconnect().compactMap { _ in
            print(NSApp.windows.map(\.className))
            return NSApp.windows.first(where: {
                $0.className == "NSPopupMenuWindow"
            })
        }.timeout(5).first().promise()

        // right-click
        window.sendEvent(mouseDown)
        let menuWindow = try await menuWindowPromise.value

        // find Print, Save As
//        let menuItems = menuWindow.contentView?.recursivelyFindMenuItemViews()
//        let printMenuItem = menuItems?.first(where: { $0.menuItem.title == UserText.printMenuItem })
//        let saveAsMenuItem = menuItems?.first(where: { $0.menuItem.title == UserText.mainMenuFileSaveAs })
//        XCTAssertNotNil(printMenuItem)
//        XCTAssertNotNil(saveAsMenuItem)
//
//        // wait for save dialog to appear
//        let saveDialogPromise = Timer.publish(every: 0.01, on: .main, in: .common).autoconnect().compactMap { _ in
//            self.window.sheets.first as? NSSavePanel
//        }.timeout(5).first().promise()
//
//        // Click Save As…
//        saveAsMenuItem?.menuItem.accessibilityPerformPress()
//
//        let saveDialog = try await saveDialogPromise.value
//        guard let url = saveDialog.url else {
//            XCTFail("no Save Dialog url")
//            return
//        }
//        try? FileManager.default.removeItem(at: url)
//
//        // wait until file is saved
//        let fileSavedPromise = Timer.publish(every: 0.01, on: .main, in: .default).autoconnect().filter { _ in
//            FileManager.default.fileExists(atPath: url.path)
//        }.timeout(5).first().promise()
//        defer {
//            try? FileManager.default.removeItem(at: url)
//        }
//
//        window.endSheet(saveDialog, returnCode: .OK)
//
//        _=try await fileSavedPromise.value
//        try XCTAssertEqual(Data(contentsOf: url), Data(contentsOf: pdfUrl))
    }

}

private extension NSView {

    private static var willOpenMenuWithEvent: ((NSMenu, NSEvent) -> Void)?

    private static let originalWillOpenMenu = {
        class_getInstanceMethod(NSView.self, #selector(NSView.willOpenMenu))!
    }()
    private static let swizzledWillOpenMenu = {
        class_getInstanceMethod(NSView.self, #selector(NSView.swizzled_willOpenMenu))!
    }()
    private static let swizzleWillOpenMenuOnce: Void = {
        method_exchangeImplementations(originalWillOpenMenu, swizzledWillOpenMenu)
    }()

    static func swizzleWillOpenMenu(with willOpenMenuWithEvent: ((NSMenu, NSEvent) -> Void)?) {
        _=swizzleWillOpenMenuOnce
        self.willOpenMenuWithEvent = willOpenMenuWithEvent
    }


    @objc dynamic func swizzled_willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        if let willOpenMenuWithEvent = Self.willOpenMenuWithEvent {
            willOpenMenuWithEvent(menu, event)
        } else {
            self.swizzled_willOpenMenu(menu, with: event) // call original
        }
    }

}
