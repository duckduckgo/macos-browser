//
//  PrivacyDebugTools.swift
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
import Combine

final class PrivacyDebugTools {
    static let urlHost = "duckduckgo.github.io"

    var current: String? = nil;
    var seen = Set<String>();
    var trackers: [DetectedTracker] = [] {
        didSet {
            trackersSubject.send(trackers)
        }
    }

    private let trackersSubject = CurrentValueSubject<[DetectedTracker], Never>([])

    public var itemsPublisher: AnyPublisher<[DetectedTracker], Never> {
        trackersSubject.eraseToAnyPublisher()
    }

    public func setCurrent(domain: String?) {
        trackers = []
        current = domain;
        seen = Set<String>();
    }

    public func tracker(tracker: DetectedTracker) -> ()? {
        guard current != nil else {
//            print("ignoring, current not set")
            return nil
        }

        guard let url = URL(string: tracker.request.pageUrl),
              let host = url.host
        else {
//            print("ignoring, host couldn't be read for incoming pageUrl")
            return nil
        }

        if case .thirdPartyRequest = tracker.type {
//            print("ignoring, third party trackers")
            return nil
        }

        guard current == host else {
//            print("ignoring, didn't match current, host: \(host), current: \(String(describing: current)) ")
            return nil
        }

//        print("current: \(String(describing: current))")
//        print("trackers: \(String(describing: trackers))")

        if seen.contains(tracker.request.url) {
            return nil;
        }
        seen.insert(tracker.request.url);
        trackers.append(tracker);
        return nil
    }

    var isEnabled: Bool {
#if DEBUG
        true
#else
        internalUserDecider.isInternalUser
#endif
    }

    private let internalUserDecider: InternalUserDecider

    init(internalUserDecider: InternalUserDecider) {
        self.internalUserDecider = internalUserDecider
    }
}

extension URL {

    var isPrivacyDebugTools: Bool {
        return host == "duckduckgo.github.io" || host == "localhost"
    }
}
