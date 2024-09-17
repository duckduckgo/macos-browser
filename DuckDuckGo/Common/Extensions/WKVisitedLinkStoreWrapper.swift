//
//  WKVisitedLinkStoreWrapper.swift
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

struct WKVisitedLinkStoreWrapper {

    fileprivate let visitedLinkStore: NSObject

    init?(visitedLinkStore: NSObject) {
        guard visitedLinkStore.responds(to: Selector.removeVisitedLinkWithURL) else {
            assertionFailure("\(visitedLinkStore) does not respond to \(Selector.removeVisitedLinkWithURL)")
            return nil
        }
        guard visitedLinkStore.responds(to: Selector.removeAll) else {
            assertionFailure("\(visitedLinkStore) does not respond to \(Selector.removeAll)")
            return nil
        }
        self.visitedLinkStore = visitedLinkStore
    }

    @MainActor
    func removeVisitedLink(with url: URL) {
        visitedLinkStore.perform(Selector.removeVisitedLinkWithURL, with: url as NSURL)
    }

    @MainActor
    func removeAll() {
        visitedLinkStore.perform(Selector.removeAll)
    }

    enum Selector {
        static let removeAll = NSSelectorFromString("removeAll")
        static let removeVisitedLinkWithURL = NSSelectorFromString("removeVisitedLinkWithURL:")
    }

}

extension WKWebViewConfiguration {

    var visitedLinkStore: WKVisitedLinkStoreWrapper? {
        get {
            guard self.responds(to: Selector.visitedLinkStore) else {
                assertionFailure("WKWebView doesn‘t respond to _visitedLinkStore")
                return nil
            }
            return (self.value(forKey: NSStringFromSelector(Selector.visitedLinkStore)) as? NSObject).flatMap(WKVisitedLinkStoreWrapper.init)
        }
        set {
            guard self.responds(to: Selector.setVisitedLinkStore) else {
                assertionFailure("WKWebView doesn‘t respond to _setVisitedLinkStore:")
                return
            }
            self.perform(Selector.setVisitedLinkStore, with: newValue?.visitedLinkStore)
        }
    }

    enum Selector {
        static let visitedLinkStore = NSSelectorFromString("_visitedLinkStore")
        static let setVisitedLinkStore = NSSelectorFromString("_setVisitedLinkStore:")
    }

}
