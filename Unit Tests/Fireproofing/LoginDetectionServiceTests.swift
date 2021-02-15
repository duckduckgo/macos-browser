//
//  LoginDetectionServiceTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

class LoginDetectionServiceTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        FireproofDomains.shared.clearAll()
    }

    func testWhenLoginAttemptedAndUserForwardedToNewPageThenLoginDetected() throws {
        let receivedLoginsExpectation = expectation(description: "Login detection expectation")
        var receivedLogins = [String]()

        let service = LoginDetectionService {
            receivedLogins.append($0)
            receivedLoginsExpectation.fulfill()
        }

        service.handle(navigationEvent: .detectedLogin(url: URL(string: "http://example.com/login")!))
        redirect(service, to: "http://example.com")

        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(receivedLogins, ["example.com"])
    }

    func testWhenLoginAttemptedInsideOAuthFlowThenLoginDetectedWhenUserForwardedToDifferentDomain() {
        let receivedLoginsExpectation = expectation(description: "Login detection expectation")
        var receivedLogins = [String]()

        let service = LoginDetectionService {
            receivedLogins.append($0)
            receivedLoginsExpectation.fulfill()
        }

        redirect(service, to: "https://accounts.google.com/o/oauth2/v2/auth")
        redirect(service, to: "https://accounts.google.com/signin/v2/challenge/pwd")
        service.handle(navigationEvent: .detectedLogin(url: URL(string: "https://accounts.google.com/signin/v2/challenge")!))
        redirect(service, to: "https://accounts.google.com/signin/v2/challenge/az?client_id")
        redirect(service, to: "https://accounts.google.com/randomPath")
        redirect(service, to: "https://example.com")

        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(receivedLogins, ["example.com"])
    }

    func testWhenLoginAttemptedInsideSSOFlowThenLoginDetectedWhenUserForwardedToDifferentDomain() {
        let receivedLoginsExpectation = expectation(description: "Login detection expectation")
        var receivedLogins = [String]()

        let service = LoginDetectionService {
            receivedLogins.append($0)
            receivedLoginsExpectation.fulfill()
        }

        load(service, url: "https://app.asana.com/-/login")
        redirect(service, to: "https://sso.host.com/saml2/idp/SSOService.php")
        load(service, url: "https://sso.host.com/module.php/core/loginuserpass.php")
        service.handle(navigationEvent: .detectedLogin(url: URL(string: "https://sso.host.com/module.php/core/loginuserpass.php")!))
        redirect(service, to: "https://sso.host.com/module.php/duosecurity/getduo.php")
        redirect(service, to: "https://app.asana.com/")

        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(receivedLogins, ["app.asana.com"])
    }

    func testWhenLoginAttemptedSkip2FAUrlsThenLoginDetectedForLatestOne() {
        let receivedLoginsExpectation = expectation(description: "Login detection expectation")
        var receivedLogins = [String]()

        let service = LoginDetectionService {
            receivedLogins.append($0)
            receivedLoginsExpectation.fulfill()
        }

        load(service, url: "https://accounts.google.com/ServiceLogin")
        load(service, url: "https://accounts.google.com/signin/v2/challenge/pwd")
        service.handle(navigationEvent: .detectedLogin(url: URL(string: "https://accounts.google.com/signin/v2/challenge/pwd")!))
        redirect(service, to: "https://accounts.google.com/signin/v2/challenge/az")
        redirect(service, to: "https://mail.google.com/mail")

        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(receivedLogins, ["mail.google.com"])
    }

    func testWhenLoginAttemptedAndUserForwardedToMultipleNewPagesThenLoginDetectedForLatestOne() {
        let receivedLoginsExpectation = expectation(description: "Login detection expectation")
        var receivedLogins = [String]()

        let service = LoginDetectionService {
            receivedLogins.append($0)
            receivedLoginsExpectation.fulfill()
        }

        service.handle(navigationEvent: .detectedLogin(url: URL(string: "http://example.com/login")!))

        load(service, url: "http://example.com", wait: true)
        load(service, url: "http://example2.com", wait: true)
        load(service, url: "http://example3.com")

        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(receivedLogins, ["example3.com"])
    }

    func testWhenLoginAttemptedAndUserForwardedToSamePageThenLoginNotDetected() {
        let receivedLoginsExpectation = expectation(description: "Login detection expectation")
        receivedLoginsExpectation.isInverted = true
        var receivedLogins = [String]()

        let service = LoginDetectionService {
            receivedLogins.append($0)
            receivedLoginsExpectation.fulfill()
        }

        service.handle(navigationEvent: .detectedLogin(url: URL(string: "http://example.com/login")!))
        load(service, url: "http://example.com/login")

        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(receivedLogins, [])
    }

    func testWhenNotDetectedLoginAttemptAndForwardedToNewPageThenLoginNotDetected() {
        let receivedLoginsExpectation = expectation(description: "Login detection expectation")
        receivedLoginsExpectation.isInverted = true
        var receivedLogins = [String]()

        let service = LoginDetectionService {
            receivedLogins.append($0)
            receivedLoginsExpectation.fulfill()
        }

        load(service, url: "http://example.com/")

        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(receivedLogins, [])
    }

    func testWhenLoginAttemptedAndUserNavigatesBackThenNewPageDoesNotDetectLogin() {
        let receivedLoginsExpectation = expectation(description: "Login detection expectation")
        receivedLoginsExpectation.isInverted = true
        var receivedLogins = [String]()

        let service = LoginDetectionService {
            receivedLogins.append($0)
            receivedLoginsExpectation.fulfill()
        }

        service.handle(navigationEvent: .detectedLogin(url: URL(string: "http://example.com/login")!))
        service.handle(navigationEvent: .userAction) // Simulate the Navigate Back action, all user actions are treated the same
        load(service, url: "http://another.example.com/")

        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(receivedLogins, [])
    }

    /// Simulates the process of loading a web page.
    private func load(_ service: LoginDetectionService, url: String, wait: Bool = false) {
        service.handle(navigationEvent: .pageBeganLoading(url: URL(string: url)!), delayAfterFinishingPageLoad: false)
        service.handle(navigationEvent: .pageFinishedLoading, delayAfterFinishingPageLoad: wait)
    }

    /// Simulates a page redirect and load event.
    private func redirect(_ service: LoginDetectionService, to url: String) {
        service.handle(navigationEvent: .redirect(url: URL(string: url)!))
        service.handle(navigationEvent: .pageFinishedLoading, delayAfterFinishingPageLoad: false)
    }

}
