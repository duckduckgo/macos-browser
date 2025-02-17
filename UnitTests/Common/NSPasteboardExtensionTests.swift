//
//  NSPasteboardExtensionTests.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

import Testing
@testable import DuckDuckGo_Privacy_Browser

@Suite("Pasteboard Extensions Unit Tests", .serialized)
final class NSPasteboardExtensionTests {

    @Test(
        "Return a URL when pasted data type represents a URL",
        arguments: [
            ("https:/www.duckduckgo.com", NSPasteboard.PasteboardType.URL),
            ("file://Users/username/Documents/example.txt", .fileURL),
            ("https://duckduckgo-my.sharepoint.com/:x:/r/personal/duckuser", .string),
        ]
    )
    func whenPasteboardDataTypeIsURLThenReturnURL(context: (urlString: String, dataType: NSPasteboard.PasteboardType)) {
        // GIVEN
        let pasteboard = NSPasteboard.test()
        pasteboard.clearContents()
        pasteboard.declareTypes([context.dataType], owner: nil)
        pasteboard.setString(context.urlString, forType: context.dataType)

        // WHEN
        let url = pasteboard.url

        // THEN
        #expect(url != nil)
    }

    @Test(
        "Return nil when pasted data type does not represent a URL",
        arguments: [
            "baby ducklings",
            "how to say duck in spanish"
        ]
    )
    func whenPasteboardDataTypeIsURLThenReturnURL(string: String) {
        // GIVEN
        let pasteboard = NSPasteboard.test()
        pasteboard.clearContents()
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(string, forType: .string)

        // WHEN
        let url = pasteboard.url

        // THEN
        #expect(url == nil)
    }

}
