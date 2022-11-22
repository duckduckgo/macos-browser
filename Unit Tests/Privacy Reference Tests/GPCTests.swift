//
//  GPCTests.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import AppKit
import BrowserServicesKit
import os.log

@testable import DuckDuckGo_Privacy_Browser

final class GPCTests: XCTestCase {
    private let testHelper = PrivacyReferenceTestHelper()
    
    private enum Resource {
        static let config = "global-privacy-control/config_reference.json"
        static let tests = "global-privacy-control/tests.json"
    }
    
    func testGPC() {
        let bundle = Bundle(for: GPCTests.self)
        let tests: GPCTestData = testHelper.decodeResource(Resource.tests, from: bundle)
        let privacyConfigurationData = testHelper.privacyConfigurationData(withConfigPath: Resource.config, bundle: bundle)
        let privacyConfiguration = testHelper.privacyConfiguration(withData: privacyConfigurationData)

        for test in tests.gpcHeader.tests {
            os_log("--------")
            
            if test.exceptPlatforms.contains(PrivacyReferenceTestHelper.privacyReferenceTestPlatformName) {
                os_log("Skipping test, ignore platform for [%s]", type: .info, test.name)
                continue
            }
            
            os_log("Testing [%s]", type: .info, test.name)

            let preferences = PrivacySecurityPreferences.shared
            preferences.gpcEnabled = test.gpcUserSettingOn
            
            let factory = GPCRequestFactory(privacySecurityPreferences: preferences)
            var testRequest = URLRequest(url: URL(string: test.requestURL)!)
            
            // Simulate request with actual headers
            testRequest.addValue("DDG-Test", forHTTPHeaderField: "User-Agent")

            let request = factory.requestForGPC(basedOn: testRequest, config: privacyConfiguration)
            
            if !test.gpcUserSettingOn {
                XCTAssertNil(request, "User opt out, request should not exist \([test.name])")
            }
            
            let hasHeader = request?.allHTTPHeaderFields?[GPCRequestFactory.Constants.secGPCHeader] != nil
            let headerValue = request?.allHTTPHeaderFields?[GPCRequestFactory.Constants.secGPCHeader]

            if test.expectGPCHeader {
                XCTAssertNotNil(request, "Request should exist if expectGPCHeader is true [\(test.name)]")
                XCTAssert(hasHeader, "Couldn't find header for [\(test.requestURL)]")
                
                if let expectedHeaderValue = test.expectGPCHeaderValue {
                    let headerValue = request?.allHTTPHeaderFields?[GPCRequestFactory.Constants.secGPCHeader]
                    XCTAssertEqual(expectedHeaderValue, headerValue, "Header should be equal [\(test.name)]")
                }
            } else {
                XCTAssertNil(headerValue, "Header value should not exist [\(test.name)]")
            }
        }
    }
}

// MARK: - GPCTestData

private struct GPCTestData: Codable {
    let gpcHeader: GpcHeader
    let gpcJavaScriptAPI: GpcJavaScriptAPI
}

// MARK: - GpcHeader

struct GpcHeader: Codable {
    let name, desc: String
    let tests: [GpcHeaderTest]
}

// MARK: - GpcHeaderTest

struct GpcHeaderTest: Codable {
    let name: String
    let siteURL: String
    let requestURL: String
    let requestType: String
    let gpcUserSettingOn, expectGPCHeader: Bool
    let expectGPCHeaderValue: String?
    let exceptPlatforms: [String]
}

// MARK: - GpcJavaScriptAPI

struct GpcJavaScriptAPI: Codable {
    let name, desc: String
    let tests: [GpcJavaScriptAPITest]
}

// MARK: - GpcJavaScriptAPITest

struct GpcJavaScriptAPITest: Codable {
    let name: String
    let siteURL: String
    let gpcUserSettingOn, expectGPCAPI: Bool
    let expectGPCAPIValue: String?
    let exceptPlatforms: [String]
    let frameURL: String?
}
