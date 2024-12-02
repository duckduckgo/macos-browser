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

import AppKit
import Carbon
import Combine
import Common
import XCTest
@testable import DuckDuckGo_Privacy_Browser

@available(macOS 12.0, *)
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
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    override func tearDown() async throws {
        window?.close()
        window = nil
        NSView.swizzleWillOpenMenu(with: nil)
    }

    func sendRightMouseClick(to view: NSView) {
        let point = view.convert(view.bounds.center, to: nil)

        let mouseDown = NSEvent.mouseEvent(with: .rightMouseDown,
                                           location: point,
                                           modifierFlags: [],
                                           timestamp: CACurrentMediaTime(),
                                           windowNumber: window.windowNumber,
                                           context: nil,
                                           eventNumber: -22966,
                                           clickCount: 1,
                                           pressure: 1)!
        let mouseUp = NSEvent.mouseEvent(with: .rightMouseUp,
                                         location: point,
                                         modifierFlags: [],
                                         timestamp: CACurrentMediaTime(),
                                         windowNumber: window.windowNumber,
                                         context: nil,
                                         eventNumber: -22966,
                                         clickCount: 1,
                                         pressure: 1)!
        view.window!.sendEvent(mouseDown)
        view.window!.sendEvent(mouseUp)
    }

    // MARK: - Tests

    @MainActor
    func testWhenPDFContextMenuPrintChosen_printDialogOpens() async throws {
        let pdfUrl = Bundle(for: Self.self).url(forResource: "test", withExtension: "pdf")!
        // open Tab with PDF
        let tab = Tab(content: .url(pdfUrl, credential: nil, source: .userEntered("")))
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        let eNewtabPageLoaded = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        try await eNewtabPageLoaded.value

        // wait for context menu to appear
        let eMenuShown = expectation(description: "menu shown")
        var menuItems = [NSMenuItem]()
        NSView.swizzleWillOpenMenu { menu, event in
            menuItems = menu.items
            menu.removeAllItems()
            eMenuShown.fulfill()
        }

        // right-click
        sendRightMouseClick(to: tab.webView)
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
        let getPrintDialog = Task { @MainActor in
            while true {
                if let sheet = self.window.sheets.first {
                    ePrintDialogShown.fulfill()
                    return sheet
                }
                try await Task.sleep(interval: 0.01)
            }
        }
        let printOperationPromise = tab.$userInteractionDialog.compactMap { (dialog: Tab.UserDialog?) -> NSPrintOperation? in
            guard case .print(let request) = dialog?.dialog else { return nil }
            return request.parameters
        }.timeout(5).first().promise()

        XCTAssertNotNil(printMenuItem.action)
        XCTAssertNotNil(printMenuItem.pdfHudRepresentedObject)

        // Click Print…
        _=printMenuItem.action.map { action in
            NSApp.sendAction(action, to: printMenuItem.target, from: printMenuItem)
        }
        if case .timedOut = await XCTWaiter(delegate: self).fulfillment(of: [ePrintDialogShown], timeout: 5) {
            getPrintDialog.cancel()
        }
        let printDialog = try await getPrintDialog.value
        defer {
            window.endSheet(printDialog, returnCode: .cancel)
        }
        let printOperation = try await printOperationPromise.value

        XCTAssertEqual(printDialog.title, UserText.printMenuItem.dropping(suffix: "…"))
        XCTAssertEqual(printOperation.pageRange, NSRange(location: 1, length: 3))
    }

    @MainActor
    func testWhenPDFMainMenuPrintChosen_printDialogOpens() async throws {
        let pdfUrl = Bundle(for: Self.self).url(forResource: "test", withExtension: "pdf")!
        // open Tab with PDF
        let tab = Tab(content: .url(pdfUrl, credential: nil, source: .userEntered("")))
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        let eNewtabPageLoaded = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        try await eNewtabPageLoaded.value

        // wait for print dialog to appear
        let ePrintDialogShown = expectation(description: "Print dialog shown")
        let getPrintDialog = Task { @MainActor in
            while true {
                if let sheet = self.window.sheets.first {
                    ePrintDialogShown.fulfill()
                    return sheet
                }
                try await Task.sleep(interval: 0.01)
            }
        }
        let printOperationPromise = tab.$userInteractionDialog.compactMap { (dialog: Tab.UserDialog?) -> NSPrintOperation? in
            guard case .print(let request) = dialog?.dialog else { return nil }
            return request.parameters
        }.timeout(5).first().promise()

        // Hit Cmd+P
        let keyDown = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command], timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "p", charactersIgnoringModifiers: "p", isARepeat: false, keyCode: UInt16(kVK_ANSI_P))!
        let keyUp = NSEvent.keyEvent(with: .keyUp, location: .zero, modifierFlags: [.command], timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "p", charactersIgnoringModifiers: "p", isARepeat: false, keyCode: UInt16(kVK_ANSI_P))!
        window.sendEvent(keyDown)
        window.sendEvent(keyUp)

        if case .timedOut = await XCTWaiter(delegate: self).fulfillment(of: [ePrintDialogShown], timeout: 5) {
            getPrintDialog.cancel()
        }
        let printDialog = try await getPrintDialog.value
        defer {
            window.endSheet(printDialog, returnCode: .cancel)
        }
        let printOperation = try await printOperationPromise.value

        XCTAssertEqual(printDialog.title, UserText.printMenuItem.dropping(suffix: "…"))
        XCTAssertEqual(printOperation.pageRange, NSRange(location: 1, length: 3))
    }

    @MainActor
    func testWhenPDFContextMenuSaveAsChosen_saveDialogOpens() async throws {
        let pdfUrl = Bundle(for: Self.self).url(forResource: "test", withExtension: "pdf")!
        // open Tab with PDF
        let tab = Tab(content: .url(pdfUrl, credential: nil, source: .userEntered("")))
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        let eNewtabPageLoaded = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        try await eNewtabPageLoaded.value

        // wait for context menu to appear
        let eMenuShown = expectation(description: "menu shown")
        var menuItems = [NSMenuItem]()
        NSView.swizzleWillOpenMenu { menu, event in
            menuItems = menu.items
            menu.removeAllItems()
            eMenuShown.fulfill()
        }

        // right-click
        sendRightMouseClick(to: tab.webView)
        await fulfillment(of: [eMenuShown])

        // find Print, Save As
        let printMenuItem = menuItems.first(where: { $0.title == UserText.printMenuItem })
        XCTAssertNotNil(printMenuItem)
        guard let saveAsMenuItem = menuItems.first(where: { $0.title == UserText.mainMenuFileSaveAs }) else {
            XCTFail("No Save As menu item")
            return
        }

        // wait for save dialog to appear
        let eSaveDialogShown = expectation(description: "Save dialog shown")
        let getSaveDialog = Task { @MainActor in
            while true {
                if let sheet = self.window.sheets.first as? NSSavePanel {
                    eSaveDialogShown.fulfill()
                    return sheet
                }
                try await Task.sleep(interval: 0.01)
            }
        }

        XCTAssertNotNil(saveAsMenuItem.action)
        XCTAssertNotNil(saveAsMenuItem.pdfHudRepresentedObject)

        let persistor = DownloadsPreferencesUserDefaultsPersistor()
        persistor.lastUsedCustomDownloadLocation = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0].path

        // Click Save As…
        _=saveAsMenuItem.action.map { action in
            NSApp.sendAction(action, to: saveAsMenuItem.target, from: saveAsMenuItem)
        }
        if case .timedOut = await XCTWaiter(delegate: self).fulfillment(of: [eSaveDialogShown], timeout: 5) {
            getSaveDialog.cancel()
        }
        let saveDialog = try await getSaveDialog.value

        guard let url = saveDialog.url else {
            XCTFail("no Save Dialog url")
            return
        }
        try? FileManager.default.removeItem(at: url)

        // wait until file is saved
        let fileSavedPromise = Timer.publish(every: 0.01, on: .main, in: .default).autoconnect().filter { _ in
            FileManager.default.fileExists(atPath: url.path)
        }.timeout(5).first().promise()
        defer {
            try? FileManager.default.removeItem(at: url)
        }

        window.endSheet(saveDialog, returnCode: .OK)

        _=try await fileSavedPromise.value
        try XCTAssertEqual(Data(contentsOf: url), Data(contentsOf: pdfUrl))
    }

    @MainActor
    func testWhenPDFMainMenuSaveAsChosen_saveDialogOpens() async throws {
        let pdfUrl = Bundle(for: Self.self).url(forResource: "test", withExtension: "pdf")!
        // open Tab with PDF
        let tab = Tab(content: .url(pdfUrl, credential: nil, source: .userEntered("")))
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        let eNewtabPageLoaded = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        try await eNewtabPageLoaded.value

        // wait for save dialog to appear
        let eSaveDialogShown = expectation(description: "Save dialog shown")
        let getSaveDialog = Task { @MainActor in
            while true {
                if let sheet = self.window.sheets.first as? NSSavePanel {
                    eSaveDialogShown.fulfill()
                    return sheet
                }
                try await Task.sleep(interval: 0.01)
            }
        }

        let persistor = DownloadsPreferencesUserDefaultsPersistor()
        persistor.lastUsedCustomDownloadLocation = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0].path

        // Hit Cmd+S
        let keyDown = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command], timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "s", charactersIgnoringModifiers: "s", isARepeat: false, keyCode: UInt16(kVK_ANSI_S))!
        let keyUp = NSEvent.keyEvent(with: .keyUp, location: .zero, modifierFlags: [.command], timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "s", charactersIgnoringModifiers: "s", isARepeat: false, keyCode: UInt16(kVK_ANSI_S))!
        window.sendEvent(keyDown)
        window.sendEvent(keyUp)

        if case .timedOut = await XCTWaiter(delegate: self).fulfillment(of: [eSaveDialogShown], timeout: 5) {
            getSaveDialog.cancel()
        }
        let saveDialog = try await getSaveDialog.value

        guard let url = saveDialog.url else {
            XCTFail("no Save Dialog url")
            return
        }
        try? FileManager.default.removeItem(at: url)

        // wait until file is saved
        let fileSavedPromise = Timer.publish(every: 0.01, on: .main, in: .default).autoconnect().filter { _ in
            FileManager.default.fileExists(atPath: url.path)
        }.timeout(5).first().promise()
        defer {
            try? FileManager.default.removeItem(at: url)
        }

        window.endSheet(saveDialog, returnCode: .OK)

        _=try await fileSavedPromise.value
        try XCTAssertEqual(Data(contentsOf: url), Data(contentsOf: pdfUrl))
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
