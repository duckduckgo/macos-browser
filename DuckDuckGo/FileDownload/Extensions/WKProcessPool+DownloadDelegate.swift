//
//  WKProcessPool+DownloadDelegate.swift
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

extension WKProcessPool {
    private static let downloadDelegateKey = "downloadDelegate"

    @nonobjc var downloadDelegate: Any? {
        get {
            return self.value(forKey: Self.downloadDelegateKey)
        }
        set {
            self.setValue(newValue, forKey: WKProcessPool.downloadDelegateKey)
            objc_setAssociatedObject(self, Self.downloadDelegateKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    @discardableResult
    func setDownloadDelegateIfNeeded(using makeDelegate: () -> LegacyWebKitDownloadDelegate)
    -> LegacyWebKitDownloadDelegate? {
        // we don't need LegacyWebKitDownloadDelegate if WKDownload is already supported
        if #available(macOS 11.3, *) { return nil }

        if let downloadDelegate = self.downloadDelegate as? LegacyWebKitDownloadDelegate {
            return downloadDelegate
        }

        let delegate = makeDelegate()
        self.downloadDelegate = delegate
        return delegate
    }

}
