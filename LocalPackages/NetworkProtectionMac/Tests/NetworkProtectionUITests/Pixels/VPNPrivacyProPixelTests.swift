//
//  VPNPrivacyProPixelTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import PixelKit
import PixelKitTestingUtilities
import XCTest
@testable import NetworkProtectionUI

final class VPNPrivacyProPixelTests: XCTestCase {

    private enum TestError: CustomNSError {
        case testError
        case underlyingError

        /// The domain of the error.
        static var errorDomain: String {
            "testDomain"
        }

        /// The error code within the given domain.
        var errorCode: Int {
            switch self {
            case .testError: return 1
            case .underlyingError: return 2
            }
        }

        /// The user-info dictionary.
        var errorUserInfo: [String: Any] {
            switch self {
            case .testError:
                return [NSUnderlyingErrorKey: TestError.underlyingError]
            case .underlyingError:
                return [:]
            }
        }
    }

    // MARK: - Test Firing Pixels

    /// This test verifies validates expectations when firing `VPNPrivacyProPixel`.
    ///
    /// This test verifies a few different things:
    ///  - That the pixel name is not changed by mistake.
    ///  - That when the pixel is fired its name and parameters are exactly what's expected.
    ///
    func testVPNPixelFireExpectations() {
        fire(VPNPrivacyProPixel.vpnAccessRevokedDialogShown,
             and: .expect(pixelName: "m_mac_vpn_access_revoked_dialog_shown"),
             file: #filePath,
             line: #line)
        fire(VPNPrivacyProPixel.vpnBetaStoppedWhenPrivacyProEnabled,
             and: .expect(pixelName: "m_mac_vpn_beta_stopped_when_privacy_pro_enabled"),
             file: #filePath,
             line: #line)
    }
}
