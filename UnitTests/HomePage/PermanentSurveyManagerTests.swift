////
////  PermanentSurveyManagerTests.swift
////
////  Copyright © 2024 DuckDuckGo. All rights reserved.
////
////  Licensed under the Apache License, Version 2.0 (the "License");
////  you may not use this file except in compliance with the License.
////  You may obtain a copy of the License at
////
////  http://www.apache.org/licenses/LICENSE-2.0
////
////  Unless required by applicable law or agreed to in writing, software
////  distributed under the License is distributed on an "AS IS" BASIS,
////  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
////  See the License for the specific language governing permissions and
////  limitations under the License.
////
//
//import XCTest
//@testable import DuckDuckGo_Privacy_Browser
//
//final class PermanentSurveyManagerTests: XCTestCase {
//
//    override func setUpWithError() throws {
//        // Put setup code here. This method is called before the invocation of each test method in the class.
//    }
//
//    override func tearDownWithError() throws {
//        // Put teardown code here. This method is called after the invocation of each test method in the class.
//    }
//
//    func testPermanentSurveyManagerReturnsExpectedSurvey() throws {
//        let newTabContinueSetUp: [String: String] = [
//            "newTabContinueSetUp": "{\"exceptions\":[],\"state\":\"enabled\",\"settings\":{\"permanentSurvey\":{\"state\":\"internal\",\"localization\":\"disabled\",\"url\":\"https://selfserve.decipherinc.com/survey/selfserve/32ab/240404?list=2\",\"firstDay\":5,\"lastDay\":8,\"sharePercentage\":60}},\"hash\":\"eb826d9079211f30d624211f44aed184\"}"
//        ]
//
//        let f = ["permanentSurvey": """
//        {
//            firstDay = 5;
//            lastDay = 8;
//            localization = disabled;
//            sharePercentage = 60;
//            state = internal;
//            url = "https://selfserve.decipherinc.com/survey/selfserve/32ab/240404?list=2";
//        }
//"""]
//
//
//        let privacyConfigManager = MockPrivacyConfigurationManager()
//        let privacyConfig = MockPrivacyConfiguration()
//        privacyConfig.featureSettings = f
//        privacyConfigManager.privacyConfig = privacyConfig
//        let manager = PermanentSurveyManager(privacyConfigurationManager: privacyConfigManager)
//        let expectedSurvey = Survey(url: URL(string: "https://selfserve.decipherinc.com/survey/selfserve/32ab/240404?list=2")!, isLocalized: true, firstDay: 5, lastDay: 9, sharePercentage: 6)
//        
//        let actualSurevy = manager.survey
//
//        XCTAssertEqual(expectedSurvey, actualSurevy)
//    }
//
//    func testPerformanceExample() throws {
//        // This is an example of a performance test case.
//        self.measure {
//            // Put the code you want to measure the time of here.
//        }
//    }
//
//}
