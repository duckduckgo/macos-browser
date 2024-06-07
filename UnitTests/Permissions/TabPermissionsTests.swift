//
//  TabPermissionsTests.swift
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
import Navigation
import XCTest

@testable import DuckDuckGo_Privacy_Browser

// swiftlint:disable opening_brace
@available(macOS 12.0, *)
final class TabPermissionsTests: XCTestCase {

    struct URLs {
        let url = URL(string: "http://testhost.com/")!
    }
    let urls = URLs()

    var contentBlockingMock: ContentBlockingMock!
    var privacyFeaturesMock: AnyPrivacyFeatures!
    var privacyConfiguration: MockPrivacyConfiguration {
        contentBlockingMock.privacyConfigurationManager.privacyConfig as! MockPrivacyConfiguration
    }

    var webViewConfiguration: WKWebViewConfiguration!
    var schemeHandler: TestSchemeHandler!

    override func setUp() {
        contentBlockingMock = ContentBlockingMock()
        privacyFeaturesMock = AppPrivacyFeatures(contentBlocking: contentBlockingMock, httpsUpgradeStore: HTTPSUpgradeStoreMock())
        // disable waiting for CBR compilation on navigation
        privacyConfiguration.isFeatureKeyEnabled = { _, _ in
            return false
        }

        schemeHandler = TestSchemeHandler()
        WKWebView.customHandlerSchemes = [.http, .https]

        webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.setURLSchemeHandler(schemeHandler, forURLScheme: URL.NavigationalScheme.http.rawValue)
        webViewConfiguration.setURLSchemeHandler(schemeHandler, forURLScheme: URL.NavigationalScheme.https.rawValue)
    }

    override func tearDown() {
        TestTabExtensionsBuilder.shared = .default
        contentBlockingMock = nil
        privacyFeaturesMock = nil
        webViewConfiguration = nil
        schemeHandler = nil
        WKWebView.customHandlerSchemes = []
    }

    // MARK: - Tests

    @MainActor
    func testWhenExternalAppPermissionRequestedAndGranted_AppIsOpened() async throws {
        let extensionsBuilder = TestTabExtensionsBuilder(load: [ExternalAppSchemeHandler.self, DownloadsTabExtension.self])
        let workspace = WorkspaceMock()
        let tab = Tab(content: .none, webViewConfiguration: webViewConfiguration, workspace: workspace, privacyFeatures: privacyFeaturesMock, extensionsBuilder: extensionsBuilder)

        schemeHandler.middleware = [{ _ in
            return .ok(.html(""))
        }]

        _=await tab.setUrl(urls.url, source: .link)?.result

        workspace.appUrl = Bundle.main.bundleURL

        let externalUrl = URL(string: "testextapp://openapp?arg=1")!

        let workspaceOpenCalledPromise = Future<URL, Never> { promise in
            workspace.onOpen = { url in
                DispatchQueue.main.async {
                    promise(.success(url))
                }
                return true
            }
        }.timeout(1).first().promise()

        var c: AnyCancellable!
        let authQueryPromise = Future<(url: URL?, domain: String), Never> { promise in
            c = tab.permissions.$authorizationQuery.sink { query in
                guard let query else { return }
                guard query.permissions == [.externalScheme(scheme: "testextapp")] else {
                    XCTFail("Unexpected permissions query \(query.permissions)")
                    return
                }
                query.submit( (granted: true, remember: false) )
                promise(.success( (url: query.url, domain: query.domain) ))
            }
        }.timeout(1).first().promise()

        tab.setUrl(externalUrl, source: .link)

        let queried = try await authQueryPromise.value
        let resultUrl = try await workspaceOpenCalledPromise.value
        XCTAssertEqual(queried.url, externalUrl)
        XCTAssertEqual(queried.domain, urls.url.host!)
        XCTAssertEqual(resultUrl, externalUrl)

        withExtendedLifetime(c) {}

        let workspaceOpenCalledPromise2 = Future<URL, Never> { promise in
            workspace.onOpen = { url in
                DispatchQueue.main.async {
                    promise(.success(url))
                }
                return true
            }
        }.timeout(1).first().promise()

        // query second time: should query again
        let authQueryPromise2 = Future<(url: URL?, domain: String), Never> { promise in
            c = tab.permissions.$authorizationQuery.sink { query in
                guard let query else { return }
                guard query.permissions == [.externalScheme(scheme: "testextapp")] else {
                    XCTFail("Unexpected permissions query \(query.permissions)")
                    return
                }
                query.submit( (granted: true, remember: false) )
                promise(.success( (url: query.url, domain: query.domain) ))
            }
        }.timeout(1).first().promise()

        tab.setUrl(externalUrl, source: .link)

        let queried2 = try await authQueryPromise2.value
        let resultUrl2 = try await workspaceOpenCalledPromise2.value
        XCTAssertEqual(queried2.url, externalUrl)
        XCTAssertEqual(queried2.domain, urls.url.host!)
        XCTAssertEqual(resultUrl2, externalUrl)

        withExtendedLifetime(c) {}
    }

    @MainActor
    func testWhenExternalAppPermissionRequestedAndGrantedAndPersisted_AppIsOpened() async throws {
        let extensionsBuilder = TestTabExtensionsBuilder(load: [ExternalAppSchemeHandler.self, DownloadsTabExtension.self])
        let workspace = WorkspaceMock()
        let tab = Tab(content: .none, webViewConfiguration: webViewConfiguration, workspace: workspace, privacyFeatures: privacyFeaturesMock, permissionManager: PermissionManagerMock(), extensionsBuilder: extensionsBuilder)

        schemeHandler.middleware = [{ _ in
            return .ok(.html(""))
        }]

        _=await tab.setUrl(urls.url, source: .link)?.result

        workspace.appUrl = Bundle.main.bundleURL

        let externalUrl = URL(string: "testextapp://openapp?arg=1")!

        let workspaceOpenCalledPromise = Future<URL, Never> { promise in
            workspace.onOpen = { url in
                DispatchQueue.main.async {
                    promise(.success(url))
                }
                return true
            }
        }.timeout(1).first().promise()

        var c: AnyCancellable!
        let authQueryPromise = Future<(url: URL?, domain: String), Never> { promise in
            c = tab.permissions.$authorizationQuery.sink { query in
                guard let query else { return }
                guard query.permissions == [.externalScheme(scheme: "testextapp")] else {
                    XCTFail("Unexpected permissions query \(query.permissions)")
                    return
                }
                query.submit( (granted: true, remember: true) )
                promise(.success( (url: query.url, domain: query.domain) ))
            }
        }.timeout(1).first().promise()

        tab.setUrl(externalUrl, source: .link)

        let queried = try await authQueryPromise.value
        let resultUrl = try await workspaceOpenCalledPromise.value
        XCTAssertEqual(queried.url, externalUrl)
        XCTAssertEqual(queried.domain, urls.url.host!)
        XCTAssertEqual(resultUrl, externalUrl)

        withExtendedLifetime(c) {}

        let workspaceOpenCalledPromise2 = Future<URL, Never> { promise in
            workspace.onOpen = { url in
                DispatchQueue.main.async {
                    promise(.success(url))
                }
                return true
            }
        }.timeout(1).first().promise()

        // query second time: shouldn‘t query again
        c = tab.permissions.$authorizationQuery.sink { query in
            guard query != nil else { return }
            XCTFail("Unexpected query")
        }

        let externalUrl2 = URL(string: "testextapp://openapp2?arg=2")!
        tab.setUrl(externalUrl2, source: .link)

        let resultUrl2 = try await workspaceOpenCalledPromise2.value
        XCTAssertEqual(resultUrl2, externalUrl2)

        withExtendedLifetime(c) {}
    }

    @MainActor
    func testWhenExternalAppPermissionEnteredByUser_permissionIsQueriedAndAppIsOpened() async throws {
        let extensionsBuilder = TestTabExtensionsBuilder(load: [ExternalAppSchemeHandler.self, DownloadsTabExtension.self])
        let workspace = WorkspaceMock()
        let tab = Tab(content: .none, webViewConfiguration: webViewConfiguration, workspace: workspace, privacyFeatures: privacyFeaturesMock, extensionsBuilder: extensionsBuilder)

        schemeHandler.middleware = [{ _ in
            return .ok(.html(""))
        }]

        workspace.appUrl = Bundle.main.bundleURL

        let externalUrl = URL(string: "testextapp://openapp?arg=1")!

        let workspaceOpenCalledPromise = Future<URL, Never> { promise in
            workspace.onOpen = { url in
                DispatchQueue.main.async {
                    promise(.success(url))
                }
                return true
            }
        }.timeout(1).first().promise()

        var c: AnyCancellable!
        let authQueryPromise = Future<(url: URL?, domain: String), Never> { promise in
            c = tab.permissions.$authorizationQuery.sink { query in
                guard let query else { return }
                guard query.permissions == [.externalScheme(scheme: "testextapp")] else {
                    XCTFail("Unexpected permissions query \(query.permissions)")
                    return
                }
                query.submit( (granted: true, remember: true) )
                promise(.success( (url: query.url, domain: query.domain) ))
            }
        }.timeout(1).first().promise()

        tab.setUrl(externalUrl, source: .userEntered(externalUrl.absoluteString))

        let queried = try await authQueryPromise.value
        let resultUrl = try await workspaceOpenCalledPromise.value
        XCTAssertEqual(queried.url, externalUrl)
        XCTAssertEqual(queried.domain, "openapp")
        XCTAssertEqual(resultUrl, externalUrl)

        withExtendedLifetime(c) {}
    }

    @MainActor
    func testWhenExternalAppPermissionRejected_AppIsNotOpened() async throws {
        let extensionsBuilder = TestTabExtensionsBuilder(load: [ExternalAppSchemeHandler.self, DownloadsTabExtension.self])
        let workspace = WorkspaceMock()
        let tab = Tab(content: .none, webViewConfiguration: webViewConfiguration, workspace: workspace, privacyFeatures: privacyFeaturesMock, extensionsBuilder: extensionsBuilder)

        schemeHandler.middleware = [{ _ in
            return .ok(.html(""))
        }]

        _=await tab.setUrl(urls.url, source: .link)?.result

        workspace.appUrl = Bundle.main.bundleURL

        let externalUrl = URL(string: "testextapp://openapp?arg=1")!

        workspace.onOpen = { _ in
            XCTFail("Unexpected Workspace.open")
            return false
        }

        var c: AnyCancellable!
        let authQueryPromise = Future<(url: URL?, domain: String), Never> { promise in
            c = tab.permissions.$authorizationQuery.sink { query in
                guard let query else { return }
                guard query.permissions == [.externalScheme(scheme: "testextapp")] else {
                    XCTFail("Unexpected permissions query \(query.permissions)")
                    return
                }
                query.submit( (granted: false, remember: false) )
                promise(.success( (url: query.url, domain: query.domain) ))
            }
        }.timeout(1).first().promise()

        tab.setUrl(externalUrl, source: .link)

        let queried = try await authQueryPromise.value

        XCTAssertEqual(queried.url, externalUrl)
        XCTAssertEqual(queried.domain, urls.url.host!)

        withExtendedLifetime(c) {}
    }

    @MainActor
    func testWhenExternalAppNotFound_AppIsNotOpened() async throws {
        let extensionsBuilder = TestTabExtensionsBuilder(load: [ExternalAppSchemeHandler.self, DownloadsTabExtension.self])
        let workspace = WorkspaceMock()
        let tab = Tab(content: .none, webViewConfiguration: webViewConfiguration, workspace: workspace, privacyFeatures: privacyFeaturesMock, extensionsBuilder: extensionsBuilder)

        schemeHandler.middleware = [{ _ in
            return .ok(.html(""))
        }]

        _=await tab.setUrl(urls.url, source: .link)?.result

        workspace.appUrl = nil

        let externalUrl = URL(string: "testextapp://openapp?arg=1")!

        workspace.onOpen = { _ in
            XCTFail("Unexpected Workspace.open")
            return false
        }

        let c = tab.permissions.$authorizationQuery.sink { query in
            guard let query else { return }
            XCTFail("Unexpected permissions query \(query)")
        }

        let result = await tab.setUrl(externalUrl, source: .link)?.result

        guard case .failure(let error) = result else {
            XCTFail("unexpected result \(String(describing: result))")
            return
        }

        XCTAssertTrue(error is DidCancelError)
        XCTAssertNil((error as? DidCancelError)?.expectedNavigations)
        withExtendedLifetime(c) {}
    }

    @MainActor
    func testWhenExternalAppNotFoundForUserEnteredUrl_SearchIsDone() async throws {
        let extensionsBuilder = TestTabExtensionsBuilder(load: [ExternalAppSchemeHandler.self, DownloadsTabExtension.self])
        let workspace = WorkspaceMock()
        let tab = Tab(content: .none, webViewConfiguration: webViewConfiguration, workspace: workspace, privacyFeatures: privacyFeaturesMock, extensionsBuilder: extensionsBuilder)

        schemeHandler.middleware = [{ _ in
            return .ok(.html(""))
        }]

        _=await tab.setUrl(urls.url, source: .link)?.result

        workspace.appUrl = nil

        let externalUrl = URL(string: "testextapp://openapp?arg=1")!

        workspace.onOpen = { _ in
            XCTFail("Unexpected Workspace.open")
            return false
        }

        let c = tab.permissions.$authorizationQuery.sink { query in
            guard let query else { return }
            XCTFail("Unexpected permissions query \(query)")
        }

        let result = await tab.setUrl(externalUrl, source: .userEntered(externalUrl.absoluteString))?.result

        guard case .failure(let error) = result,
              let error = error as? DidCancelError,
              let navigation = error.expectedNavigations?.first else {
            XCTFail("unexpected result \(String(describing: result))")
            return
        }

        _=await navigation.result
        XCTAssertEqual(tab.content, .contentFromURL(URL.makeSearchUrl(from: externalUrl.absoluteString), source: .webViewUpdated))

        withExtendedLifetime(c) {}
    }

    @MainActor
    func testWhenSessionIsRestored_externalAppIsNotOpened() {
        var eDidCancel: XCTestExpectation!
        let extensionsBuilder = TestTabExtensionsBuilder(load: [ExternalAppSchemeHandler.self, DownloadsTabExtension.self]) { builder in { _, _ in
            builder.add {
                TestsClosureNavigationResponderTabExtension(.init { _, _ in
                    .next
                } didCancel: { _, _ in
                    eDidCancel.fulfill()
                } navigationDidFinish: { nav in
                    XCTFail("unexpected navigationDidFinish \(nav)")
                } navigationDidFail: { nav, error in
                    XCTFail("unexpected navigationDidFail \(nav) with \(error)")
                })
            }
        }}

        let workspace = WorkspaceMock()
        workspace.appUrl = Bundle.main.bundleURL
        let externalUrl = URL(string: "testextapp://openapp?arg=1")!

        eDidCancel = expectation(description: "didCancel external app should be called")

        // shouldn‘t open external app when restoring session from interaction state
        let tab = Tab(content: .url(externalUrl, source: .pendingStateRestoration), webViewConfiguration: webViewConfiguration, workspace: workspace, privacyFeatures: privacyFeaturesMock, extensionsBuilder: extensionsBuilder, shouldLoadInBackground: true)

        var c = tab.permissions.$authorizationQuery.sink { query in
            guard let query else { return }
            XCTFail("Unexpected permissions query \(query)")
        }

        waitForExpectations(timeout: 1)

        let permissionRequest = expectation(description: "Permission requested")
        c = tab.permissions.$authorizationQuery.sink { query in
            guard let query else { return }
            guard query.permissions == [.externalScheme(scheme: "testextapp")] else {
                XCTFail("Unexpected permissions query \(query.permissions)")
                return
            }
            permissionRequest.fulfill()
        }
        eDidCancel = expectation(description: "external app permission requested")

        // but should open auth query on reload
        tab.setContent(.url(externalUrl, source: .reload))

        waitForExpectations(timeout: 2)

        withExtendedLifetime(c) {}
    }

}

final class WorkspaceMock: Workspace {

    var appUrl: URL?
    func urlForApplication(toOpen url: URL) -> URL? {
        appUrl
    }

    var onOpen: ((URL) -> Bool)?
    func open(_ url: URL) -> Bool {
        return onOpen?(url) ?? false
    }

    var onOpenURLs: (([URL], String?, NSWorkspace.LaunchOptions, NSAppleEventDescriptor?, AutoreleasingUnsafeMutablePointer<NSArray?>?) -> Bool)?
    func open(_ urls: [URL], withAppBundleIdentifier bundleIdentifier: String?, options: NSWorkspace.LaunchOptions, additionalEventParamDescriptor descriptor: NSAppleEventDescriptor?, launchIdentifiers identifiers: AutoreleasingUnsafeMutablePointer<NSArray?>?) -> Bool {
        return onOpenURLs?(urls, bundleIdentifier, options, descriptor, identifiers) ?? false
    }

}
