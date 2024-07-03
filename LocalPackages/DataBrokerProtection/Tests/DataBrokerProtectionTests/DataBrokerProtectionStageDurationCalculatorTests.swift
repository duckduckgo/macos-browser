//
//  DataBrokerProtectionStageDurationCalculatorTests.swift
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

import BrowserServicesKit
import Foundation
import SecureStorage
import XCTest

@testable import DataBrokerProtection

final class DataBrokerProtectionStageDurationCalculatorTests: XCTestCase {
    let handler = MockDataBrokerProtectionPixelsHandler()

    override func tearDown() {
        handler.clear()
    }

    func testWhenErrorIs404_thenWeFireScanFailedPixel() {
        let sut = DataBrokerProtectionStageDurationCalculator(dataBroker: "broker", dataBrokerVersion: "1.1.1", handler: handler)

        sut.fireScanError(error: DataBrokerProtectionError.httpError(code: 404))

        XCTAssertTrue(MockDataBrokerProtectionPixelsHandler.lastPixelsFired.count == 1)

        if let failurePixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.last{
            switch failurePixel {
            case .scanFailed(let broker, let brokerVersion, _, _, _):
                XCTAssertEqual(broker, "broker")
                XCTAssertEqual(brokerVersion, "1.1.1")
            default: XCTFail("The scan failed pixel should be fired")
            }
        } else {
            XCTFail("A pixel should be fired")
        }
    }

    func testWhenErrorIs403_thenWeFireScanErrorPixelWithClientErrorCategory() {
        let sut = DataBrokerProtectionStageDurationCalculator(dataBroker: "broker", dataBrokerVersion: "1.1.1", handler: handler)

        sut.fireScanError(error: DataBrokerProtectionError.httpError(code: 403))

        XCTAssertTrue(MockDataBrokerProtectionPixelsHandler.lastPixelsFired.count == 1)

        if let failurePixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.last{
            switch failurePixel {
            case .scanError(_, _, _, let category, _, _):
                XCTAssertEqual(category, ErrorCategory.clientError(httpCode: 403).toString)
            default: XCTFail("The scan error pixel should be fired")
            }
        } else {
            XCTFail("A pixel should be fired")
        }
    }

    func testWhenErrorIs500_thenWeFireScanErrorPixelWithServerErrorCategory() {
        let sut = DataBrokerProtectionStageDurationCalculator(dataBroker: "broker", dataBrokerVersion: "1.1.1", handler: handler)

        sut.fireScanError(error: DataBrokerProtectionError.httpError(code: 500))

        XCTAssertTrue(MockDataBrokerProtectionPixelsHandler.lastPixelsFired.count == 1)

        if let failurePixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.last{
            switch failurePixel {
            case .scanError(_, _, _, let category, _, _):
                XCTAssertEqual(category, ErrorCategory.serverError(httpCode: 500).toString)
            default: XCTFail("The scan error pixel should be fired")
            }
        } else {
            XCTFail("A pixel should be fired")
        }
    }

    func testWhenErrorIsNotHttp_thenWeFireScanErrorPixelWithValidationErrorCategory() {
        let sut = DataBrokerProtectionStageDurationCalculator(dataBroker: "broker", dataBrokerVersion: "1.1.1", handler: handler)

        sut.fireScanError(error: DataBrokerProtectionError.actionFailed(actionID: "Action-ID", message: "Some message"))

        XCTAssertTrue(MockDataBrokerProtectionPixelsHandler.lastPixelsFired.count == 1)

        if let failurePixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.last{
            switch failurePixel {
            case .scanError(_, _, _, let category, _, _):
                XCTAssertEqual(category, ErrorCategory.validationError.toString)
            default: XCTFail("The scan error pixel should be fired")
            }
        } else {
            XCTFail("A pixel should be fired")
        }
    }

    func testWhenErrorIsNotDBPErrorButItIsNSURL_thenWeFireScanErrorPixelWithNetworkErrorErrorCategory() {
        let sut = DataBrokerProtectionStageDurationCalculator(dataBroker: "broker", dataBrokerVersion: "1.1.1", handler: handler)
        let nsURLError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)

        sut.fireScanError(error: nsURLError)

        XCTAssertTrue(MockDataBrokerProtectionPixelsHandler.lastPixelsFired.count == 1)

        if let failurePixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.last{
            switch failurePixel {
            case .scanError(_, _, _, let category, _, _):
                XCTAssertEqual(category, ErrorCategory.networkError.toString)
            default: XCTFail("The scan error pixel should be fired")
            }
        } else {
            XCTFail("A pixel should be fired")
        }
    }

    func testWhenErrorIsSecureVaultError_thenWeFireScanErorrPixelWithDatabaseErrorCategory() {
        let sut = DataBrokerProtectionStageDurationCalculator(dataBroker: "broker", dataBrokerVersion: "1.1.1", handler: handler)
        let error = SecureStorageError.encodingFailed

        sut.fireScanError(error: error)

        XCTAssertTrue(MockDataBrokerProtectionPixelsHandler.lastPixelsFired.count == 1)

        if let failurePixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.last{
            switch failurePixel {
            case .scanError(_, _, _, let category, _, _):
                XCTAssertEqual(category, "database-error-SecureVaultError-13")
            default: XCTFail("The scan error pixel should be fired")
            }
        } else {
            XCTFail("A pixel should be fired")
        }
    }

    func testWhenErrorIsNotDBPErrorAndNotURL_thenWeFireScanErrorPixelWithUnclassifiedErrorCategory() {
        let sut = DataBrokerProtectionStageDurationCalculator(dataBroker: "broker", dataBrokerVersion: "1.1.1", handler: handler)
        let error = NSError(domain: NSCocoaErrorDomain, code: -1)

        sut.fireScanError(error: error)

        XCTAssertTrue(MockDataBrokerProtectionPixelsHandler.lastPixelsFired.count == 1)

        if let failurePixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.last{
            switch failurePixel {
            case .scanError(_, _, _, let category, _, _):
                XCTAssertEqual(category, ErrorCategory.unclassified.toString)
            default: XCTFail("The scan error pixel should be fired")
            }
        } else {
            XCTFail("A pixel should be fired")
        }
    }
}
