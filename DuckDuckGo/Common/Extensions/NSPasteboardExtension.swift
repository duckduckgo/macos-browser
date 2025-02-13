//
//  NSPasteboardExtension.swift
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

import AppKit
import Foundation

extension NSPasteboard {

    func copy(_ string: String) {
        clearContents()
        setString(string, forType: .string)
    }

    func copy(_ url: URL, withString string: String? = nil) {
        clearContents()
        declareTypes([.URL], owner: nil)
        (url as NSURL).write(to: self)
        setString(string ?? url.absoluteString, forType: .string)
    }

    var url: URL? {
        if let urlString = self.string(forType: .URL) ?? self.string(forType: .fileURL) {
            return URL(string: urlString)
        }
        if let string = self.string(forType: .string), let url = URL(string: string), url.scheme != nil {
            return url
        }
        return nil
    }
}

extension NSPasteboard.PasteboardType {
    static let urlName = NSPasteboard.PasteboardType(rawValue: "public.url-name")
}
