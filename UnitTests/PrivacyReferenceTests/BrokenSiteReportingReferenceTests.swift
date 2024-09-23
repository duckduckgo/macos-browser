//
//  BrokenSiteReportingReferenceTests.swift
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
import PrivacyDashboard

@testable import Networking
@testable import DuckDuckGo_Privacy_Browser

final class BrokenSiteReportingReferenceTests: XCTestCase {
    private let testHelper = PrivacyReferenceTestHelper()

    struct MockError: LocalizedError {
        let description: String

        init(_ description: String) {
            self.description = description
        }

        var errorDescription: String? {
            description
        }

        var localizedDescription: String? {
            description
        }
    }

    private enum Resource {
        static let tests = "privacy-reference-tests/broken-site-reporting/tests.json"
    }

    private func makeURLRequest(with parameters: [String: String]) -> URLRequest {
        APIRequest.Headers.setUserAgent("")
        var params = parameters
        params["test"] = "1"
        let configuration = APIRequest.Configuration(url: URL.pixelUrl(forPixelNamed: NonStandardPixel.brokenSiteReport.name),
                                                     queryParameters: params,
                                                     allowedQueryReservedCharacters: BrokenSiteReport.allowedQueryReservedCharacters)
        return configuration.request
    }

    func testBrokenSiteReporting() {
        let bundle = Bundle(for: BrokenSiteReportingReferenceTests.self)
        let testData: BrokenSiteReportingTestData = testHelper.decodeResource(Resource.tests, from: bundle)

        for test in testData.reportURL.tests {
            if test.exceptPlatforms.contains(PrivacyReferenceTestHelper.privacyReferenceTestPlatformName) {
                Logger.general.debug("Skipping test, ignore platform for [\(test.name)]")
                continue
            }

            Logger.general.debug("Testing [\(test.name)]")

            var errors: [Error]?
            if let errs = test.errorDescriptions {
                errors = errs.map { MockError($0) }
            }

            let breakage = BrokenSiteReport(siteUrl: test.siteURL,
                                            category: test.category,
                                            description: test.providedDescription,
                                            osVersion: test.os ?? "",
                                            manufacturer: "Apple",
                                            upgradedHttps: test.wasUpgraded,
                                            tdsETag: test.blocklistVersion,
                                            configVersion: test.remoteConfigVersion,
                                            blockedTrackerDomains: test.blockedTrackers,
                                            installedSurrogates: test.surrogates,
                                            isGPCEnabled: test.gpcEnabled ?? false,
                                            ampURL: "",
                                            urlParametersRemoved: false,
                                            protectionsState: test.protectionsEnabled,
                                            reportFlow: .appMenu,
                                            errors: errors,
                                            httpStatusCodes: test.httpErrorCodes ?? [],
                                            openerContext: nil,
                                            vpnOn: false,
                                            jsPerformance: nil,
                                            userRefreshCount: 0)

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
                let pattern = "[?&]\(param.name)=\(param.value)[&$]?"

                guard let regex = try? NSRegularExpression(pattern: pattern,
                                                           options: []) else {
                    XCTFail("Couldn't create regex")
                    return
                }

                let match = regex.matches(in: absoluteURL, range: NSRange(location: 0, length: absoluteURL.count))

                if param.name == "errorDescriptions" {
                    // `localizedDescription` adds class information to the error. The value is not standardized across platforms
                    // so we'll just check the result is an array of strings
                    guard let params = URLComponents(string: absoluteURL)?.queryItems else {
                        XCTFail("Unable to parse query parameters from \(absoluteURL)")
                        return
                    }
                    var errorsFound = false
                    for queryItem in params {
                        if queryItem.name != param.name { continue }
                        errorsFound = true
                        XCTAssert((queryItem.value?.split(separator: ",").count ?? 0) > 1, "Error descriptions should return an array of strings. Parsed: \(queryItem.value ?? "")")
                    }
                    XCTAssert(errorsFound, "Param [\(param.name)] with value [\(param.value)] not found in [\(absoluteURL)]")
                } else {
                    XCTAssertEqual(match.count, 1, "Param [\(param.name)] with value [\(param.value)] not found in [\(absoluteURL)]")
                }
            }
        }
    }

}

// MARK: - BrokenSiteReportingTestData

private struct BrokenSiteReportingTestData: Codable {
    let reportURL: ReportURL
}

// MARK: - ReportURL

private struct ReportURL: Codable {
    let name: String
    let tests: [Test]
}

// MARK: - Test

private struct Test: Codable {
    let name: String
    let siteURL: URL
    let wasUpgraded: Bool
    let category: String
    let providedDescription: String?
    let blockedTrackers, surrogates: [String]
    let atb, blocklistVersion: String
    let remoteConfigVersion: String?
    let expectReportURLPrefix: String
    let expectReportURLParams: [ExpectReportURLParam]
    let exceptPlatforms: [String]
    let manufacturer, model, os: String?
    let gpcEnabled: Bool?
    let protectionsEnabled: Bool
    let errorDescriptions: [String]?
    let httpErrorCodes: [Int]?
}

// MARK: - ExpectReportURLParam

private struct ExpectReportURLParam: Codable {
    let name, value: String
}
