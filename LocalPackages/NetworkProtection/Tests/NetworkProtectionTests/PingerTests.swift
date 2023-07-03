//
//  PingerTests.swift
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

import Foundation
import Network
import XCTest
@testable import NetworkProtection

final class PingerTests: XCTestCase {

    func testPingValidIpShouldSucceed() {
        let ip = IPv4Address("8.8.8.8")!
        let timeout = 3.0

        let e = expectation(description: "ready")
        Task {
            do {
                let pinger = Pinger(ip: ip, timeout: timeout, log: .default)
                let r = try await pinger.ping().get()

                XCTAssertEqual(r.ip, ip)
                XCTAssertLessThan(20, r.bytesCount)
                XCTAssertEqual(r.seq, 0)
                XCTAssertLessThanOrEqual(r.time/1000, timeout)
                XCTAssertNotEqual(r.ttl, 0)

            } catch {
                XCTFail("error: \(error)")
            }
            e.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    func testPingValidIpAsyncShouldSucceed() {
        let ip = IPv4Address("8.8.8.8")!
        let timeout = 3.0

        let e = expectation(description: "ready")

        Task {
            do {
                let pinger = Pinger(ip: ip, timeout: timeout, log: .default)
                let r = try await pinger.ping().get()

                XCTAssertEqual(r.ip, ip)
                XCTAssertLessThan(20, r.bytesCount)
                XCTAssertEqual(r.seq, 0)
                XCTAssertLessThanOrEqual(r.time/1000, timeout)
                XCTAssertNotEqual(r.ttl, 0)

                // ping twice
                let r2 = try await pinger.ping().get()

                XCTAssertEqual(r2.ip, ip)
                XCTAssertEqual(r.bytesCount, r2.bytesCount)
                XCTAssertEqual(r2.seq, 1)
                XCTAssertLessThanOrEqual(r2.time/1000, timeout)
                XCTAssertEqual(r.ttl, r2.ttl)

            } catch {
                XCTFail("error: \(error)")
            }
            e.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    func testNonExistentIpShouldTimeout() throws {
        let ip = IPv4Address("111.2.155.2")!
        let timeout = 0.2

        let e = expectation(description: "ready")

        let pinger = Pinger(ip: ip, timeout: timeout, log: .default)
        pinger.ping { result in
            XCTAssert(Thread.isMainThread)
            do {
                _=try result.get()
                XCTFail("ping should fail")
            } catch Pinger.PingError.timeout(.select) {
                // pass
            } catch {
                XCTFail("error: \(error)")
            }
            e.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    func testNonExistentIpAsyncShouldTimeout() throws {
        let ip = IPv4Address("111.2.155.2")!
        let timeout = 0.2

        let e = expectation(description: "ready")
        Task {
            do {
                let pinger = Pinger(ip: ip, timeout: timeout, log: .default)
                _=try await pinger.ping().get()

                XCTFail("ping should fail")

            } catch Pinger.PingError.timeout(.select) {
                // pass
            } catch {
                XCTFail("error: \(error)")
            }
            e.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

}
