//
//  BackForwardListItem.swift
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

import Navigation
import WebKit

struct BackForwardListItem: Hashable {

    enum Kind: Hashable {
        case url(URL)
        case goBackToClose(URL?)
    }
    let kind: Kind
    let title: String?
    let identity: HistoryItemIdentity?

    var url: URL? {
        switch kind {
        case .url(let url): return url
        case .goBackToClose(let url): return url
        }
    }

    init(kind: Kind, title: String?, identity: HistoryItemIdentity?) {
        self.kind = kind
        self.title = title
        self.identity = identity
    }

    init(_ wkItem: WKBackForwardListItem) {
        self.init(kind: .url(wkItem.url), title: wkItem.tabTitle ?? wkItem.title, identity: wkItem.identity)
    }

}

extension [BackForwardListItem] {
    init(_ items: [WKBackForwardListItem]) {
        self = items.map(BackForwardListItem.init)
    }
}
