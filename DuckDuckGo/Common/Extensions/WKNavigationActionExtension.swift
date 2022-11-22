//
//  WKNavigationActionExtension.swift
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

import WebKit

extension WKNavigationAction {

    private static var isSourceFrameSwizzled: Bool = false
    private static let originalSourceFrame = {
        class_getInstanceMethod(WKNavigationAction.self, #selector(getter: sourceFrame))
    }()
    private static let swizzledSourceFrame = {
        class_getInstanceMethod(WKNavigationAction.self, #selector(getter: swizzledSourceFrame))
    }()

    static func swizzleNonnullSourceFrameFix() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !self.isSourceFrameSwizzled else { return }
        guard let originalSourceFrame = originalSourceFrame,
              let swizzledSourceFrame = swizzledSourceFrame
        else {
            assertionFailure("Methods not available")
            return
        }

        method_exchangeImplementations(originalSourceFrame, swizzledSourceFrame)
        self.isSourceFrameSwizzled = true
    }
    // In this cruel reality the source frame IS Nullable for initial load events, but in that case the target frame shouldn‘t be nil
    @objc var swizzledSourceFrame: WKFrameInfo {
        withUnsafePointer(to: self.swizzledSourceFrame) { $0.withMemoryRebound(to: WKFrameInfo?.self, capacity: 1) { $0 } }.pointee
            ?? self.targetFrame
            ?? .fake() // and just in case it is
    }

    var isTargetingMainFrame: Bool {
        targetFrame?.isMainFrame ?? false
    }

    var shouldDownload: Bool {
        if #available(macOS 11.3, *) {
            return shouldPerformDownload
        } else {
            return _shouldPerformDownload
        }
    }

    private static let _isUserInitiated = "_isUserInitiated"

    static var supportsIsUserInitiated: Bool {
        instancesRespond(to: NSSelectorFromString(_isUserInitiated))
    }

    var isUserInitiated: Bool {
        guard Self.supportsIsUserInitiated else { return true }
        return self.value(forKey: Self._isUserInitiated) as? Bool ?? true
    }

    var isMiddleClick: Bool {
        self.buttonNumber == 4
    }

}

private class FakeWKFrameInfo: NSObject {
    @objc var isMainFrame: Bool { false }
    @objc var request: URLRequest { .null }
    @objc var securityOrigin: WKSecurityOrigin { .fake() }
    @objc var webView: WKWebView? { nil }

    @objc var _handle: NSObject? { nil } // swiftlint:disable:this identifier_name
    @objc var _parentFrameHandle: NSObject? { nil } // swiftlint:disable:this identifier_name
}

private extension URLRequest {
    static let null = NSURLRequest() as URLRequest
}

@objc private class FakeSecurityOrigin: NSObject {
    @objc var `protocol`: String { "" }
    @objc var host: String { "" }
    @objc var port: Int { 0 }
}

private extension WKSecurityOrigin {
    static func fake() -> WKSecurityOrigin {
        withExtendedLifetime(FakeSecurityOrigin()) {
            withUnsafePointer(to: $0) { $0.withMemoryRebound(to: WKSecurityOrigin.self, capacity: 1) { $0 }}.pointee
        }
    }
}

private extension WKFrameInfo {
    static func fake() -> WKFrameInfo {
        withExtendedLifetime(FakeWKFrameInfo()) {
            withUnsafePointer(to: $0) { $0.withMemoryRebound(to: WKFrameInfo.self, capacity: 1) { $0 }}.pointee
        }
    }
}
