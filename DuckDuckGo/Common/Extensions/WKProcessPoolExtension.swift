//
//  WKProcessPoolExtension.swift
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

import WebKit

extension WKProcessPool {

#if DEBUG

    private static let webViewsUsingProcessPoolKey = UnsafeRawPointer(bitPattern: "webViewsUsingProcessPoolKey".hashValue)!
    var webViewsUsingProcessPool: Set<NSValue> {
        get {
            objc_getAssociatedObject(self, Self.webViewsUsingProcessPoolKey) as? Set<NSValue> ?? []
        }
        set {
            objc_setAssociatedObject(self, Self.webViewsUsingProcessPoolKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    private static let knownUserContentControllersKey = UnsafeRawPointer(bitPattern: "knownUserContentControllersKey".hashValue)!
    final class WeakUserContentControllerRef: NSObject {
        weak var userContentController: WKUserContentController?
        init(userContentController: WKUserContentController? = nil) {
            self.userContentController = userContentController
        }
    }
    var knownUserContentControllers: Set<WeakUserContentControllerRef> {
        get {
            objc_getAssociatedObject(self, Self.knownUserContentControllersKey) as? Set<WeakUserContentControllerRef> ?? []
        }
        set {
            objc_setAssociatedObject(self, Self.knownUserContentControllersKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

#endif

}
