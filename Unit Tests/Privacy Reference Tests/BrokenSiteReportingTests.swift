//
//  BrokenSiteReportingTests.swift
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
import os.log
import BrowserServicesKit

@testable import DuckDuckGo_Privacy_Browser

final class BrokenSiteReportingTests: XCTestCase {
    private let testHelper = PrivacyReferenceTestHelper()
    
    private enum Resource {
        static let tests = "broken-site-reporting/tests.json"
    }
    
    private func makeURLRequest(with parameters: [String: String]) -> URLRequest {
        APIRequest.urlRequestFor(
            url: URL.pixelUrl(forPixelNamed: Pixel.Event.brokenSiteReport.name),
            method: .get,
            parameters: parameters,
            allowedQueryReservedCharacters: WebsiteBreakageSender.allowedQueryReservedCharacters,
            headers: [:],
            timeoutInterval: 60
        )
    }

    func testBrokenSiteReporting() {
        let bundle = Bundle(for: BrokenSiteReportingTests.self)
        let testData: BrokenSiteReportingTestData = testHelper.decodeResource(Resource.tests, from: bundle)

        for test in testData.reportURL.tests {
            if test.exceptPlatforms.contains(PrivacyReferenceTestHelper.privacyReferenceTestPlatformName) {
                os_log("Skipping test, ignore platform for [%s]", type: .info, test.name)
                continue
            }
            
            os_log("Testing [%s]", type: .info, test.name)
            
            var category = WebsiteBreakage.Category(rawValue: test.category)
            
            let breakage = WebsiteBreakage(category: category,
                            description: nil,
                            siteUrlString: test.siteURL,
                            osVersion: test.os ?? "",
                            upgradedHttps: test.wasUpgraded,
                            tdsETag: nil,
                            blockedTrackerDomains: test.blockedTrackers,
                            installedSurrogates: test.surrogates,
                            isGPCEnabled: test.gpcEnabled ?? false,
                            ampURL: "",
                            urlParametersRemoved: false,
                            manufacturer: test.manufacturer ?? "")
            
            let request = makeURLRequest(with: breakage.requestParameters)
            
            guard let requestURL = request.url else {
                XCTFail("Couldn't create request URL")
                return
            }
            
            let absoluteURL = requestURL.absoluteString
            
            if test.expectReportURLPrefix.count > 0 {
                XCTAssertTrue(requestURL.absoluteString.contains(test.expectReportURLPrefix), "Prefix [\(test.expectReportURLPrefix)] not found")
            }
            
            for param in test.expectReportURLParams {
                let pattern = "[?&]\(param.name)=\(param.value)[&$]"
                
                guard let regex = try? NSRegularExpression(pattern: pattern,
                                                           options: []) else {
                    XCTFail("Couldn't create regex")
                    return
                }
                
                let match = regex.matches(in: absoluteURL, range: NSRange(location: 0, length: absoluteURL.count))
                
                XCTAssertEqual(match.count, 1, "Param [\(param.name)] with value [\(param.value)] not found in [\(absoluteURL)]")
            }
        }
    }

}

// MARK: - BrokenSiteReportingTestData

struct BrokenSiteReportingTestData: Codable {
    let reportURL: ReportURL
}

// MARK: - ReportURL

struct ReportURL: Codable {
    let name: String
    let tests: [Test]
}

// MARK: - Test

struct Test: Codable {
    let name: String
    let siteURL: String
    let wasUpgraded: Bool
    let category: String
    let blockedTrackers, surrogates: [String]
    let atb, blocklistVersion: String
    let expectReportURLPrefix: String
    let expectReportURLParams: [ExpectReportURLParam]
    let exceptPlatforms: [String]
    let manufacturer, model, os: String?
    let gpcEnabled: Bool?
}

// MARK: - ExpectReportURLParam

struct ExpectReportURLParam: Codable {
    let name, value: String
}
