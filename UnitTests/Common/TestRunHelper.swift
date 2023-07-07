//
//  TestRunHelper.swift
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

import DependencyInjection
import Foundation
import XCTest
@testable import DuckDuckGo_Privacy_Browser

@objc(TestRunHelper)
final class TestRunHelper: NSObject {
    @objc(sharedInstance) static let shared = TestRunHelper()

    override init() {
        super.init()
        XCTestObservationCenter.shared.addTestObserver(self)

        // set NSApp.runType to appropriate test run type
        _=NSApplication.swizzleRunTypeOnce
        // allow mocking NSApp.currentEvent
        _=NSApplication.swizzleCurrentEventOnce

        // dedicate temporary directory for tests
        _=FileManager.swizzleTemporaryDirectoryOnce
        FileManager.default.cleanupTemporaryDirectory()

        // provide extra info on failures
        _=NSError.swizzleLocalizedDescriptionOnce

        // add code to be run on Unit Tests startup here...

    }

}

extension TestRunHelper: XCTestObservation {

    func testBundleWillStart(_ testBundle: Bundle) {
        NotificationCenter.default.post(name: .testBundleWillStart, object: testBundle)
    }

    func testBundleDidFinish(_ testBundle: Bundle) {
        NotificationCenter.default.post(name: .testBundleDidFinish, object: testBundle)
        if case .integrationTests = NSApp.runType {
            FileManager.default.cleanupTemporaryDirectory()
        }
    }

    func testSuiteWillStart(_ testSuite: XCTestSuite) {
        NotificationCenter.default.post(name: .testSuiteWillStart, object: testSuite)
    }

    func testSuiteDidFinish(_ testSuite: XCTestSuite) {
        NotificationCenter.default.post(name: .testSuiteDidFinish, object: testSuite)
    }

    @MainActor
    func testCaseWillStart(_ testCase: XCTestCase) {
        NotificationCenter.default.post(name: .testCaseWillStart, object: testCase)

        if case .unitTests = NSApp.runType {
            // cleanup dedicated temporary directory before each test run
            FileManager.default.cleanupTemporaryDirectory()

            // set default Unit Tests dependencies
            TestDependencyProvider.set(ContentBlockingMock(), for: \Tab.contentBlocking)
            TestDependencyProvider.set(TestTabExtensionsBuilder.shared , for: \Tab.tabExtensionsBuilder)
            TestDependencyProvider.set(FaviconManagerMock(), for: \Tab.faviconManagement)
            TestDependencyProvider.set(PinnedTabsManager(), for: \Tab.pinnedTabsManager)
            TestDependencyProvider.set(PinnedTabsManager(), for: \TabCollectionViewModel.pinnedTabsManager)

            TestDependencyProvider.set(BookmarkStoreMock(), for: \LocalBookmarkManager.bookmarkStore)
            TestDependencyProvider.set(LocalBookmarkManager(dependencyProvider: TestDependencyProvider.for(LocalBookmarkManager.self)),
                                       for: \BookmarksBarViewController.bookmarkManager)
            TestDependencyProvider.set(FileDownloadManagerMock(), for: \DownloadListCoordinator.downloadManager)
            TestDependencyProvider.set(DownloadListCoordinator(dependencyProvider: TestDependencyProvider.for(DownloadListCoordinator.self), store: DownloadListStoreMock()), for: \NavigationBarViewController.downloadListCoordinator)
            TestDependencyProvider.set(HistoryCoordinatingMock(), for: \AddressBarViewController.historyCoordinating)

            TestDependencyProvider.set(nil, for: \Fire.syncService)
            TestDependencyProvider.set({ nil }, for: \LocalBookmarkManager.syncService)
            let fire = Fire(dependencyProvider: TestDependencyProvider.for(Fire.self))
            TestDependencyProvider.set(FireViewModel(fire: fire), for: \HomePageViewController.fireViewModel)
        }
        NSApp.swizzled_currentEvent = nil

    }

    func testCaseDidFinish(_ testCase: XCTestCase) {
        NotificationCenter.default.post(name: .testCaseDidFinish, object: testCase)

        if case .unitTests = NSApp.runType {
            // cleanup dedicated temporary directory after each test run
            FileManager.default.cleanupTemporaryDirectory()
        }
        NSApp.swizzled_currentEvent = nil
    }

}

extension Notification.Name {

    static let testBundleWillStart = Notification.Name(rawValue: "testBundleWillStart")
    static let testBundleDidFinish = Notification.Name(rawValue: "testBundleDidFinish")
    static let testSuiteWillStart = Notification.Name(rawValue: "testSuiteWillStart")
    static let testSuiteDidFinish = Notification.Name(rawValue: "testSuiteDidFinish")
    static let testCaseWillStart = Notification.Name(rawValue: "testCaseWillStart")
    static let testCaseDidFinish = Notification.Name(rawValue: "testCaseDidFinish")

}

extension NSApplication {

    // NSApp.runType - returns .unitTests or .integrationTests when running tests

    static var swizzleRunTypeOnce: Void = {
        let runTypeMethod = class_getInstanceMethod(NSApplication.self, #selector(getter: NSApplication.runType))!
        let swizzledRunTypeMethod = class_getInstanceMethod(NSApplication.self, #selector(NSApplication.swizzled_runType))!

        method_exchangeImplementations(runTypeMethod, swizzledRunTypeMethod)
    }()

    @objc dynamic func swizzled_runType() -> NSApplication.RunType {
        RunType(bundle: Bundle(for: TestRunHelper.self))
    }

    // allow mocking NSApp.currentEvent

    static var swizzleCurrentEventOnce: Void = {
        let curentEventMethod = class_getInstanceMethod(NSApplication.self, #selector(getter: NSApplication.currentEvent))!
        let swizzledCurentEventMethod = class_getInstanceMethod(NSApplication.self, #selector(getter: NSApplication.swizzled_currentEvent))!

        method_exchangeImplementations(curentEventMethod, swizzledCurentEventMethod)
    }()

    private static let currentEventKey = UnsafeRawPointer(bitPattern: "currentEventKey".hashValue)!
    @objc dynamic var swizzled_currentEvent: NSEvent? {
        get {
            objc_getAssociatedObject(self, Self.currentEventKey) as? NSEvent
                ?? self.swizzled_currentEvent // call original
        }
        set {
            objc_setAssociatedObject(self, Self.currentEventKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

}

extension NSApplication.RunType {

    init(bundle: Bundle) {
        if bundle.displayName!.hasPrefix("Unit") {
            self = .unitTests
        } else if bundle.displayName!.hasPrefix("Integration") {
            self = .integrationTests
        } else {
            self = .uiTests
        }
    }

}

struct TestDependencyProvider: DependencyStorageProtocol {

    static var subscribeToTestCaseDidFinishOnce: Void = {
        NotificationCenter.default.addObserver(forName: .testCaseDidFinish, object: nil, queue: nil) { _ in
            _storage = nil
        }
    }()

    static var _storage: [String: Any]?
    static var storage: [String: Any] {
        get {
            if let _storage {
                return _storage
            }
            _=subscribeToTestCaseDidFinishOnce
            _storage = [:]
            return _storage!
        }
        set {
            _storage = newValue
        }
    }

    public static func `set`<Owner: Injectable, T>(_ value: T, for keyPath: KeyPath<Owner, T>) {
        storage[Owner.description(forInjectedKeyPath: keyPath)!] = value
    }

    var _storage: [AnyKeyPath: Any] // swiftlint:disable:this identifier_name

    private init<Owner: Injectable>(ownerType: Owner.Type) {
        _storage = Owner.getAllDependencyProviderKeyPaths().reduce(into: [:]) { storage, keyPath in
            func getter<T>(_ valueType: T.Type) -> () -> T {
                {
                    Self.storage[Owner.description(forInjectedKeyPath: keyPath)!] as? T ??
                        { fatalError("Dependency for \(keyPath) should be explicitly set") }()
                }
            }
            storage[keyPath] = _openExistential(type(of: keyPath).valueType, do: getter) as Any
        }
    }

    func value<T>(for keyPath: AnyKeyPath) -> T {
        fatalError("Unexpected value(for:)")
    }

    static func `for`<Owner: Injectable>(_ ownerType: Owner.Type) -> Owner.DependencyStorage {
        withUnsafePointer(to: TestDependencyProvider(ownerType: ownerType)) {
            $0.withMemoryRebound(to: Owner.DependencyStorage.self, capacity: 1) { $0.pointee }
        }
    }

}
