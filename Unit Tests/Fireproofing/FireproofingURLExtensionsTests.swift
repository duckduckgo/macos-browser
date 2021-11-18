//
//  FireproofingURLExtensionsTests.swift
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

final class FireproofingURLExtensionsTests: XCTestCase {

    func testOAuthPatterns() {
        XCTAssert(URL(string: "https://accounts.google.com/o/oauth2/v2/auth?client_id=123456&scope=openid")!.isOAuthURL)
        XCTAssert(URL(string: "https://appleid.apple.com/auth/authorize?client_id=com.spotify.accounts")!.isOAuthURL)
        XCTAssert(URL(string: "https://www.amazon.com/ap/oa?client_id=amzn1.application-oa2-client&scope=profile")!.isOAuthURL)
        XCTAssert(URL(string: "https://auth.atlassian.com/authorize")!.isOAuthURL)
        XCTAssert(URL(string: "https://www.facebook.com/dialog/oauth?display=touch&response_type=code")!.isOAuthURL)
        XCTAssert(URL(string: "https://www.facebook.com/v2.0/dialog/oauth?display=touch&response_type=code")!.isOAuthURL)
        XCTAssert(URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!.isOAuthURL)
        XCTAssert(URL(string: "https://www.linkedin.com/oauth/v2/authorization")!.isOAuthURL)
        XCTAssert(URL(string: "https://github.com/login/oauth/authorize")!.isOAuthURL)
        XCTAssert(URL(string: "https://api.twitter.com/oauth/authorize?oauth_token")!.isOAuthURL)
        XCTAssert(URL(string: "https://api.duosecurity.com/oauth/v1/authorize?response_type=code&client_id")!.isOAuthURL)
        XCTAssert(URL(string: "https://api-f6f4ecbe.duosecurity.com/frame/prompt?sid=frameless")!.isOAuthURL)

        XCTAssertFalse(URL(string: "https://duckduckgo.com")!.isOAuthURL)
        XCTAssertFalse(URL(string: "example.com")!.isOAuthURL)
    }

    func testTwoFactorPatterns() {
        XCTAssert(URL(string: "https://accounts.google.com/signin/v2/challenge/az?client_id")!.isTwoFactorURL)
        XCTAssert(URL(string: "https://sso.duckduckgo.com/module.php/duosecurity/getduo.php")!.isTwoFactorURL)
        XCTAssert(URL(string: "https://www.amazon.com/ap/cvf/approval")!.isTwoFactorURL)

        XCTAssertFalse(URL(string: "https://duckduckgo.com")!.isTwoFactorURL)
        XCTAssertFalse(URL(string: "example.com")!.isTwoFactorURL)
    }

    func testSSOPatterns() {
        XCTAssert(URL(string: "https://sso.host.com/saml2/idp/SSOService.php")!.isSingleSignOnURL)

        XCTAssertFalse(URL(string: "https://duckduckgo.com")!.isSingleSignOnURL)
        XCTAssertFalse(URL(string: "example.com")!.isSingleSignOnURL)
    }

    func testLoginPatterns() {
        XCTAssert(URL(string: "https://sso.host.com/module.php/core/loginuserpass.php")!.isLoginURL)
        XCTAssert(URL(string: "https://login.microsoftonline.com/")!.isLoginURL)
        XCTAssert(URL(string: "https://example.com/login")!.isLoginURL)
        XCTAssert(URL(string: "https://example.com/sign-in")!.isLoginURL)
        XCTAssert(URL(string: "https://example.com/signin")!.isLoginURL)
        XCTAssert(URL(string: "https://example.com/session")!.isLoginURL)

        XCTAssertFalse(URL(string: "https://duckduckgo.com")!.isLoginURL)
        XCTAssertFalse(URL(string: "example.com")!.isLoginURL)
    }

}
