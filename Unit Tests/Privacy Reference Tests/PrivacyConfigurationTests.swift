//
//  PrivacyConfigurationTests.swift
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
import BrowserServicesKit

final class PrivacyConfigurationTests: XCTestCase {
    private let testHelper = PrivacyReferenceTestHelper()

    private enum Resource {
        static let configRootPath = "privacy-configuration"
        static let tests = "privacy-configuration/tests.json"
    }
    
    /*
     for $testSet in test.json
       loadRemoteConfig($testSet.referenceConfig)

       for $test in $testSet
         $enabled = isEnabled(
             feature=$test.featureName,
             url=$test.siteURL,
             frame=$test.frameURL,
             script=$test.scriptURL
         )

         expect($enabled === $test.expectFeatureEnabled)
     */
    
    func testPrivacyConfiguration() {
        let bundle = Bundle(for: PrivacyConfigurationTests.self)
        let testData: TestData = testHelper.decodeResource(Resource.tests, from: bundle)

        for testConfig in testData.testConfigs {
            let path = "\(Resource.configRootPath)/\(testConfig.referenceConfig)"
            let privacyConfigurationData = testHelper.privacyConfiguration(withConfigPath: path,
                                                                           bundle: bundle)

            for test in testConfig.tests {
                if test.exceptPlatforms.contains(.macosBrowser) {
                    print("SKIPPING TEST \(test.name)")
                    continue
                }
                
                guard let feature = PrivacyFeature(rawValue: test.featureName) else {
                    print("CANT CREATE FEATURE \(test.featureName)")
                    continue
                }
                
                let isEnabled = privacyConfigurationData.isFeature(feature, enabledForDomain: test.siteURL)

                let list = privacyConfigurationData.exceptionsList(forFeature: feature)
                let testInfo = "\nName: \(test.name)\nFeature: \(test.featureName)\nsiteURL: \(test.siteURL)\nConfig: \(testConfig.referenceConfig)\nExceptionList: \(list)\nisEnabled: \(isEnabled)"

                XCTAssertEqual(isEnabled, test.expectFeatureEnabled, testInfo)
            }
        }
    }
}

private struct TestData: Codable {
    let testConfigs: [TestConfig]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: TestConfig].self)
        testConfigs = dict.compactMap { _, values in values }
    }
}

// MARK: - AboutBlank
private struct TestConfig: Codable {
    let name, desc, referenceConfig: String
    let tests: [Test]
    
}

// MARK: - Test
private struct Test: Codable {
    let name, featureName: String
    let siteURL: String
    let frameURL: String?
    let expectFeatureEnabled: Bool
    let exceptPlatforms: [ExceptPlatform]
    let scriptURL: String?
}

private enum ExceptPlatform: String, Codable {
    case androidBrowser = "android-browser"
    case iosBrowser = "ios-browser"
    case macosBrowser = "macos-browser"
    case safariExtension = "safari-extension"
    case webExtension = "web-extension"
    case windowsBrowser = "windows-browser"
}
