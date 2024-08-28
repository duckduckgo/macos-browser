//
//  SecurityScopedFileURLController.swift
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

import Foundation
import Common
import os.log
import BrowserServicesKit

/// Manages security-scoped resource access to a file URL.
///
/// This class is designed to consume unbalanced `startAccessingSecurityScopedResource` calls and ensure proper
/// resource cleanup by calling `stopAccessingSecurityScopedResource` the appropriate number of times
/// to end the resource access securely.
///
/// - Note: Used in conjunction with NSURL extension swizzling the `startAccessingSecurityScopedResource` and
///         `stopAccessingSecurityScopedResource` methods to accurately reflect the current number of start and stop calls.
///         The number is reflected in the associated `URL.sandboxExtensionRetainCount` value.
final class SecurityScopedFileURLController {
    private(set) var url: URL
    let isManagingSecurityScope: Bool

    /// Initializes a new instance of `SecurityScopedFileURLController` with the provided URL and security-scoped resource handling options.
    ///
    /// - Parameters:
    ///   - url: The URL of the file to manage.
    ///   - manageSecurityScope: A Boolean value indicating whether the controller should manage the URL security scope access (i.e. call stop and end accessing resource methods).
    ///   - logger: An optional logger instance for logging file operations. Defaults to disabled.
    /// - Note: when `manageSecurityScope` is `true` access to the represented URL will be stopped for the whole app on the controller deallocation.
    init(url: URL, manageSecurityScope: Bool = true) {
        assert(url.isFileURL)
#if APPSTORE
        let didStartAccess = manageSecurityScope && url.startAccessingSecurityScopedResource()
#else
        let didStartAccess = false
#endif
        self.url = url
        self.isManagingSecurityScope = didStartAccess
        Logger.fileDownload.debug("\(didStartAccess ? "🧪 " : "")SecurityScopedFileURLController.init: \(url.sandboxExtensionRetainCount) – \"\(url.path)\"")
    }

    func updateUrlKeepingSandboxExtensionRetainCount(_ newURL: URL) {
        guard newURL as NSURL !== url as NSURL else { return }

        for _ in 0..<url.sandboxExtensionRetainCount {
            newURL.consumeUnbalancedStartAccessingSecurityScopedResource()
        }
        self.url = newURL
    }

    deinit {
        if isManagingSecurityScope {
            let url = url
            Logger.fileDownload.debug("\(self.isManagingSecurityScope ? "🪓 " : "")SecurityScopedFileURLController.deinit: \(url.sandboxExtensionRetainCount) – \"\(url.path)\"")
            for _ in 0..<(url as NSURL).sandboxExtensionRetainCount {
                url.stopAccessingSecurityScopedResource()
            }

#if DEBUG && APPSTORE
            url.ensureUrlIsNotWritable {
            #if SANDBOX_TEST_TOOL
                Logger.fileDownload.log("❗️ url \(url.path) is still writable after stopping access to it")
                fatalError("❗️ url \(url.path) is still writable after stopping access to it")
            #else
                breakByRaisingSigInt("❗️ url \(url.path) is still writable after stopping access to it")
            #endif
            }
#endif
        }
    }

}

extension NSURL {

    private static let originalStopAccessingSecurityScopedResource = {
        class_getInstanceMethod(NSURL.self, #selector(NSURL.stopAccessingSecurityScopedResource))!
    }()
    private static let swizzledStopAccessingSecurityScopedResource = {
        class_getInstanceMethod(NSURL.self, #selector(NSURL.swizzled_stopAccessingSecurityScopedResource))!
    }()
    private static let originalStartAccessingSecurityScopedResource = {
        class_getInstanceMethod(NSURL.self, #selector(NSURL.startAccessingSecurityScopedResource))!
    }()
    private static let swizzledStartAccessingSecurityScopedResource = {
        class_getInstanceMethod(NSURL.self, #selector(NSURL.swizzled_startAccessingSecurityScopedResource))!
    }()

    private static let _swizzleStartStopAccessingSecurityScopedResourceOnce: Void = {
        method_exchangeImplementations(originalStopAccessingSecurityScopedResource, swizzledStopAccessingSecurityScopedResource)
        method_exchangeImplementations(originalStartAccessingSecurityScopedResource, swizzledStartAccessingSecurityScopedResource)
    }()
    @objc static func swizzleStartStopAccessingSecurityScopedResourceOnce() {
        _=_swizzleStartStopAccessingSecurityScopedResourceOnce
    }

    @objc private dynamic func swizzled_startAccessingSecurityScopedResource() -> Bool {
        if self.swizzled_startAccessingSecurityScopedResource() /* call original */ {
            sandboxExtensionRetainCount += 1
            return true
        }
        return false
    }

    @objc private dynamic func swizzled_stopAccessingSecurityScopedResource() {
        self.swizzled_stopAccessingSecurityScopedResource() // call original

        var sandboxExtensionRetainCount = self.sandboxExtensionRetainCount
        if sandboxExtensionRetainCount > 0 {
            sandboxExtensionRetainCount -= 1
            self.sandboxExtensionRetainCount = sandboxExtensionRetainCount
        }
    }

    private static let sandboxExtensionRetainCountKey = UnsafeRawPointer(bitPattern: "sandboxExtensionRetainCountKey".hashValue)!
    fileprivate(set) var sandboxExtensionRetainCount: Int {
        get {
            (objc_getAssociatedObject(self, Self.sandboxExtensionRetainCountKey) as? NSNumber)?.intValue ?? 0
        }
        set {
            objc_setAssociatedObject(self, Self.sandboxExtensionRetainCountKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN)
#if DEBUG
            if newValue > 0 {
                NSURL.activeSecurityScopedUrlUsages.insert(.init(url: self))
            } else {
                NSURL.activeSecurityScopedUrlUsages.remove(.init(url: self))
            }
#endif
        }
    }

#if DEBUG
    struct SecurityScopedUrlUsage: Hashable {
        let url: NSURL
        // hash url as object address
        func hash(into hasher: inout Hasher) {
            hasher.combine(ObjectIdentifier(url))
        }
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.url === rhs.url
        }
    }
    static var activeSecurityScopedUrlUsages: Set<SecurityScopedUrlUsage> = []
#endif

}

extension URL {

    /// The number of times the security-scoped resource associated with the URL has been accessed
    /// using `startAccessingSecurityScopedResource` without a corresponding call to
    /// `stopAccessingSecurityScopedResource`. This property provides a count of active accesses
    /// to the security-scoped resource, helping manage resource cleanup and ensure proper
    /// handling of security-scoped resources.
    ///
    /// - Note: Accessing this property requires NSURL extension swizzling of `startAccessingSecurityScopedResource`
    ///         and `stopAccessingSecurityScopedResource` methods to accurately track the count.
    var sandboxExtensionRetainCount: Int {
        (self as NSURL).sandboxExtensionRetainCount
    }

    func consumeUnbalancedStartAccessingSecurityScopedResource() {
        (self as NSURL).sandboxExtensionRetainCount += 1
    }

}
