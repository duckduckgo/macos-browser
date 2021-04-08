//
//  UrlEventListener.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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
import os.log

final class UrlEventListener {

    private let handler: ((URL) -> Void)

    init(handler: @escaping ((URL) -> Void)) {
        self.handler = handler
    }

    func listen() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleUrlEvent(event:reply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc func handleUrlEvent(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let path = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue?.removingPercentEncoding else {
            os_log("UrlEventListener: unable to determine path", type: .error)
            Pixel.fire(.debug(event: .appOpenURLFailed,
                              error: NSError(domain: "CouldNotGetPath", code: -1, userInfo: nil)))
            return
        }

        guard let url = URL(string: path) ?? URL(string: path.replacingOccurrences(of: " ", with: "%20")) else {
            os_log("UrlEventListener: failed to construct URL from path %s", type: .error, path)
            Pixel.fire(.debug(event: .appOpenURLFailed,
                              error: NSError(domain: "CouldNotConstructURL", code: -1, userInfo: nil)))
            return
        }

        handler(url)
    }

}
