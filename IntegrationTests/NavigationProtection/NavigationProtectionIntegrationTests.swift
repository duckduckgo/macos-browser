//
//  NavigationProtectionIntegrationTests.swift
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

import Combine
import Common
import Navigation
import os.log
import XCTest

@testable import DuckDuckGo_Privacy_Browser

@available(macOS 12.0, *)
class NavigationProtectionIntegrationTests: XCTestCase {

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

        WebTrackingProtectionPreferences.shared.isGPCEnabled = true
    }

    // MARK: - Tests

    @MainActor
    func testAMPLinks() async throws {
        // disable GPC redirects
        WebTrackingProtectionPreferences.shared.isGPCEnabled = false

        var onDidCancel: ((NavigationAction, [ExpectedNavigation]?) -> Void)?
        var onWillStart: ((Navigation) -> Void)?
        let extensionsBuilder = TestTabExtensionsBuilder { builder in { _, _ in
            builder.add {
                TestsClosureNavigationResponderTabExtension(.init(didCancel: { onDidCancel?($0, $1) }, willStart: { onWillStart?($0) }))
            }
        }}
        let tab = Tab(content: .none, extensionsBuilder: extensionsBuilder)
        window = WindowsManager.openNewWindow(with: tab)!

        let url = URL(string: "https://privacy-test-pages.site/privacy-protections/amp/")!
        _=try await tab.setUrl(url, source: .link)?.result.get()

        let itemsCount = try await tab.webView.evaluateJavaScript("document.getElementsByTagName('li').length") as Int? ?? 0
        XCTAssertTrue(itemsCount > 0, "no items")

        // go through links on the page
        for i in 0..<itemsCount {
            print("processing", i)
            // open test page if needed
            if tab.content.urlForWebView != url {
                _=try await tab.setUrl(url, source: .link)?.result.get()
            }

            // extract "Expected" URL
            guard let name: String = try await tab.webView.evaluateJavaScript("document.getElementsByTagName('li')[\(i)].getElementsByTagName('a')[0].innerText"),
                  let expected: String = try await tab.webView.evaluateJavaScript("document.getElementsByTagName('li')[\(i)].getElementsByClassName('expected')[0].innerText"),
                  let expectedUrl = URL(string: expected.lowercased().dropping(prefix: "expected: "))
            else {
                XCTFail("Could not parse element at \(i)")
                continue
            }

            // await for NavigationAction to pass to the last (test) responder (and cancel it after)
            let navigationWillStartPromise = Future<URL?, Never> { promise in
                onDidCancel = { _, expectedNavigations in
                    guard let expectedNavigation = expectedNavigations?.first else {
                        XCTFail("no expected navigations for \(expectedUrl) (#\(i + 1) \(name))")
                        promise(.success(nil))
                        return
                    }
                    expectedNavigation.prependResponder { navigationAction, _ in
                        if navigationAction.url.absoluteString.lowercased() != expectedUrl.absoluteString.lowercased() {
                            // give it another try
                            print("proceeding with \(navigationAction.url) (expected: \(expectedUrl)) – #\(i + 1) \(name)")
                            return .next
                        }
                        promise(.success(navigationAction.url))
                        onDidCancel = nil

                        return .cancel
                    } willStart: { [unowned tab] navigation in
                        XCTFail("#\(i + 1) \(name) got to loading \(navigation.navigationAction.url.absoluteString)")
                        tab.stopLoading()
                        promise(.success(navigation.navigationAction.url))
                    }
                }
                onWillStart = { navigation in
                    tab.stopLoading()
                    promise(.success(navigation.navigationAction.url))
                }
            }.timeout(10, "#\(i + 1) \(name)").first().promise()

            // click
            try await tab.webView.evaluateJavaScript("(function() { document.getElementsByTagName('li')[\(i)].getElementsByTagName('a')[0].click(); })()") as Void?
            // get the NavigationAction url
            let resultUrl = try await navigationWillStartPromise.value

            XCTAssertEqual(resultUrl?.absoluteString.lowercased(), expectedUrl.absoluteString.lowercased(), "(#\(i + 1) \(name))")
        }
    }

    @MainActor
    func testReferrerTrimming() async throws {
        // disable GPC redirects
        WebTrackingProtectionPreferences.shared.isGPCEnabled = false

        var lastRedirectedNavigation: Navigation?
        var onDidFinish: ((Navigation) -> Void)?
        let extensionsBuilder = TestTabExtensionsBuilder { builder in { _, _ in
            builder.add {
                TestsClosureNavigationResponderTabExtension(.init(redirected: { _, navigation in
                    lastRedirectedNavigation = navigation
                }, navigationDidFinish: { navigation in
                    if navigation.navigationAction.url.absoluteString.hasSuffix("testid="), navigation !== lastRedirectedNavigation {
                        onDidFinish?(navigation)
                    }
                }))
            }
        }}
        let tab = Tab(content: .none, extensionsBuilder: extensionsBuilder)
        window = WindowsManager.openNewWindow(with: tab)!

        let url = URL(string: "https://privacy-test-pages.site/privacy-protections/referrer-trimming/")!
        _=try await tab.setUrl(url, source: .link)?.result.get()

        // run test
        try await tab.webView.evaluateJavaScript("(function() { document.getElementById('start').click(); })()") as Void?

        _=try await Future<Void, Never> { promise in
            onDidFinish = { _ in
                if tab.webView.url?.absoluteString == url.absoluteString {
                    promise(.success( () ))
                }
            }
        }.timeout(40, "didFinish").first().promise().value

        // download results
        let persistor = DownloadsPreferencesUserDefaultsPersistor()
        persistor.selectedDownloadLocation = FileManager.default.temporaryDirectory.absoluteString
        // download task promise
        let downloadTaskPromise = FileDownloadManager.shared.downloadsPublisher.timeout(5).first().promise()
        for i in 0...4 {
            do {
                try await tab.webView.evaluateJavaScript("(function() { document.getElementById('download').click(); })()") as Void?
                try await Task.sleep(nanoseconds: 300.asNanos)
                break
            } catch {
                if i == 4 {
                    XCTFail((error as NSError).userInfo.description)
                }
            }
        }

        // wait for the download to complete
        let fileUrl = try await downloadTaskPromise.value.output
            .timeout(1, scheduler: DispatchQueue.main) { .init(TimeoutError(description: "failed to download") as NSError) }.first().promise().get()

        // print(try! String(contentsOf: fileUrl))
        let results = try JSONDecoder().decode(Results.self, from: Data(contentsOf: fileUrl)).results
        XCTAssertTrue(results.count > 0)
        for result in results {
            if result.id.hasPrefix("1p") {
                XCTAssertEqual(result.value?.string, "https://privacy-test-pages.site/privacy-protections/referrer-trimming/", result.id)
            } else {
                XCTAssertEqual(result.value?.string, "https://privacy-test-pages.site/", result.id)
            }
        }
    }

    @MainActor
    func testGPC() async throws {
        let tab = Tab(content: .none)
        window = WindowsManager.openNewWindow(with: tab)!
        let tabViewModel = (window.contentViewController as! MainViewController).browserTabViewController.tabViewModel!

        let url = URL(string: "https://privacy-test-pages.site/privacy-protections/gpc/")!
        // disable GPC redirects
        WebTrackingProtectionPreferences.shared.isGPCEnabled = false
        _=try await tab.setUrl(url, source: .link)?.result.get()

        // enable GPC redirects
        WebTrackingProtectionPreferences.shared.isGPCEnabled = true

        // expect popup to open and then close
        var oldValue: TabViewModel! = self.tabViewModel
        let comingBackToFirstTabPromise = mainViewController.tabCollectionViewModel
            .$selectedTabViewModel
            .filter { newValue in
                if newValue === tabViewModel && oldValue !== newValue {
                    // returning back from popup window: pass published value further
                    return true
                }
                oldValue = newValue
                return false
            }
            .asVoid()
            .timeout(10)
            .first()
            .promise()

        // run test
        try await tab.webView.evaluateJavaScript("(function() { document.getElementById('start').click(); })()") as Void?

        // await for popup to open and close
        _=try await comingBackToFirstTabPromise.value

        // download results
        var results: Results!
        let expected: [Results.Result] = [
            .init(id: "top frame header", value: .string("1")),
            .init(id: "top frame JS API", value: .null),
            .init(id: "frame header", value: nil),
            .init(id: "frame JS API", value: .bool(true)),
            .init(id: "subequest header", value: nil),
        ]
        // FIX ME: this is not actually correct value, see https://app.asana.com/0/0/1204317492529614/f
        let unexpectedButOk: [Results.Result] = [
            .init(id: "top frame header", value: .string("1")),
            .init(id: "top frame JS API", value: .null),
            .init(id: "frame header", value: nil),
            .init(id: "frame JS API", value: .bool(false)),
            .init(id: "subequest header", value: nil),
        ]
        // retry several times for correct results to come
        for _ in 0..<5 {
            let persistor = DownloadsPreferencesUserDefaultsPersistor()
            persistor.selectedDownloadLocation = FileManager.default.temporaryDirectory.absoluteString
            let downloadTaskFuture = FileDownloadManager.shared.downloadsPublisher.timeout(5).first().promise()
            try await tab.webView.evaluateJavaScript("(function() { document.getElementById('download').click(); })()") as Void?

            let fileUrl = try await downloadTaskFuture.value.output
                .timeout(1, scheduler: DispatchQueue.main) { .init(TimeoutError() as NSError) }.first().promise().get()

            // print(try! String(contentsOf: fileUrl))
            results = try JSONDecoder().decode(Results.self, from: Data(contentsOf: fileUrl))

            if results.results == expected || results.results == unexpectedButOk {
                break
            }
            try await Task.sleep(nanoseconds: 300.asNanos)
        }
        if results.results != expected {
            XCTAssertEqual(results.results, unexpectedButOk)
        } else {
            XCTAssertEqual(results.results, expected)
        }
    }
}

private extension Tab {
    var navDelegate: DistributedNavigationDelegate! {
        self.value(forKeyPath: Tab.objcNavigationDelegateKeyPath) as? DistributedNavigationDelegate
    }
}

private struct Results: Decodable {
    struct Result: Decodable, Equatable {
        enum CodingKeys: CodingKey {
            case id
            case value
        }
        enum Value: Decodable, Equatable {
            case string(String)
            case bool(Bool)
            case null

            var string: String? {
                if case .string(let string) = self { return string }
                return nil
            }
        }
        let id: String
        let value: Value?
        init(id: String, value: Value?) {
            self.id = id
            self.value = value
        }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try container.decode(String.self, forKey: CodingKeys.id)

            if container.contains(CodingKeys.value) {
                if let string = try? container.decode(String.self, forKey: CodingKeys.value) {
                    self.value = .string(string)
                } else if try container.decodeNil(forKey: CodingKeys.value) {
                    self.value = .null
                } else {
                    let bool = try container.decode(Bool.self, forKey: CodingKeys.value)
                    self.value = .bool(bool)
                }
            } else {
                self.value = nil
            }
        }
    }
    let results: [Result]
}
