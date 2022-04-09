//
//  CrashReportTests.swift
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

class CrashReportTests: XCTestCase {

    func testWhenParsingIPSCrashReports_ThenCrashReportDataDoesNotIncludeIdentifyingInformation() {
        let bundle = Bundle(for: CrashReportTests.self)
        let url = bundle.resourceURL!.appendingPathComponent("DuckDuckGo-ExampleCrash.ips")

        let report = JSONCrashReport(url: url)

        XCTAssertNotNil(report.content)
        XCTAssertNotNil(report.contentData)

        // Verify that the content includes the slice ID
        XCTAssertTrue(report.content!.contains("7fc6ff2c-a85d-3116-96d9-9368ec955ba1"))

        // Verify that the content does not include the sleepWakeUUID anywhere in the report
        XCTAssertFalse(report.content!.contains("2384290E-F858-4024-9488-11D3FF94B4DD"))

        // Verify that the content does not include the device identitier
        XCTAssertFalse(report.content!.contains("483B097A-A969-596F-9F2A-357347BB1DEC"))

        // Verify that the content does not include any experiment rollout identifiers
        XCTAssertFalse(report.content!.contains("602ad4dac86151000cf27e46"))
        XCTAssertFalse(report.content!.contains("5fc94383418129005b4e9ae0"))
        XCTAssertFalse(report.content!.contains("5ffde50ce2aacd000d47a95f"))
        XCTAssertFalse(report.content!.contains("60da5e84ab0ca017dace9abf"))
        XCTAssertFalse(report.content!.contains("607844aa04477260f58a8077"))
        XCTAssertFalse(report.content!.contains("601d9415f79519000ccd4b69"))

        // Verify that the sleepWakeUUID is definitely empty
        XCTAssert(report.content!.contains(#"sleepWakeUUID":"<removed>"#))
        XCTAssert(report.content!.contains(#"deviceIdentifierForVendor":"<removed>"#))
    }

    private func ipsCrashURL() -> URL {
        let bundle = Bundle(for: CrashReportTests.self)
        return bundle.resourceURL!.appendingPathComponent("DuckDuckGo-ExampleCrash.ips")
    }

}
