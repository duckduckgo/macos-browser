//
//  AVCaptureDevice+SwizzledAuthState.swift
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

import Foundation
import AVFoundation

extension AVCaptureDevice {
    private static var authorizationStatusForMediaType: ((AVMediaType, inout AVAuthorizationStatus) -> Void)?
    private static var isSwizzled: Bool { authorizationStatusForMediaType != nil }

    private static let originalAuthorizationStatusForMediaType = {
        class_getClassMethod(AVCaptureDevice.self, #selector(authorizationStatus(for:)))
    }()
    private static let swizzledAuthorizationStatusForMediaType = {
        class_getClassMethod(AVCaptureDevice.self, #selector(swizzled_authorizationStatus(for:)))
    }()

    static func swizzleAuthorizationStatusForMediaType(with replacement: @escaping ((AVMediaType, inout AVAuthorizationStatus) -> Void)) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !self.isSwizzled else { return }
        guard let originalAuthorizationStatusForMediaType = originalAuthorizationStatusForMediaType,
              let swizzledAuthorizationStatusForMediaType = swizzledAuthorizationStatusForMediaType
        else {
            assertionFailure("Methods not available")
            return
        }

        method_exchangeImplementations(originalAuthorizationStatusForMediaType, swizzledAuthorizationStatusForMediaType)
        self.authorizationStatusForMediaType = replacement
    }

    static func restoreAuthorizationStatusForMediaType() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard self.isSwizzled else { return }
        guard let originalAuthorizationStatusForMediaType = originalAuthorizationStatusForMediaType,
              let swizzledAuthorizationStatusForMediaType = swizzledAuthorizationStatusForMediaType
        else {
            assertionFailure("Methods not available")
            return
        }

        method_exchangeImplementations(originalAuthorizationStatusForMediaType, swizzledAuthorizationStatusForMediaType)
        self.authorizationStatusForMediaType = nil
    }

    @objc dynamic private static func swizzled_authorizationStatus(for mediaType: AVMediaType) -> AVAuthorizationStatus {
        var result = self.swizzled_authorizationStatus(for: mediaType) // call the original
        if Thread.isMainThread,
           let authorizationStatusForMediaType = Self.authorizationStatusForMediaType {
            authorizationStatusForMediaType(mediaType, &result)
        }
        return result
    }

}
