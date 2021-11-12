//
//  InvalidatedBackForwardListItem.swift
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

final class InvalidatedBackForwardListItem: NSObject, NSSecureCoding {

    private enum NSSecureCodingKeys {
        static let url = "url"
        static let title = "title"
        static let index = "index"
    }

    static var supportsSecureCoding: Bool { true }
    
    let url: URL
    let title: String?
    let index: Int

    init(url: URL, title: String, index: Int) {
        self.url = url
        self.title = title
        self.index = index
    }

    init(backForwardListItem: WKBackForwardListItem, index: Int) {
        self.url = backForwardListItem.url
        self.title = backForwardListItem.title
        self.index = index
    }

    init?(coder decoder: NSCoder) {
        guard let url: NSURL = decoder.decodeIfPresent(at: NSSecureCodingKeys.url),
              let index: Int = decoder.decodeIfPresent(at: NSSecureCodingKeys.index)
        else { return nil }

        self.url = url as URL
        self.title = decoder.decodeIfPresent(at: NSSecureCodingKeys.title)
        self.index = index
    }

    func encode(with coder: NSCoder) {
        coder.encode(url as NSURL, forKey: NSSecureCodingKeys.url)
        coder.encode(title, forKey: NSSecureCodingKeys.title)
        coder.encode(index, forKey: NSSecureCodingKeys.index)
    }

}
