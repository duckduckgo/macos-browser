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

    var safeSourceFrame: WKFrameInfo? {
        // In this cruel reality the source frame IS Nullable for initial load events
        withUnsafePointer(to: self.sourceFrame) { $0.withMemoryRebound(to: WKFrameInfo?.self, capacity: 1) { $0 } }.pointee
    }

}
