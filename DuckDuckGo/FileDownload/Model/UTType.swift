//
//  UTType.swift
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

import Foundation
import UniformTypeIdentifiers

struct UTType: RawRepresentable, Hashable {
    static let html = UTType(rawValue: kUTTypeHTML)
    static let webArchive = UTType(rawValue: kUTTypeWebArchive)
    static let pdf = UTType(rawValue: kUTTypePDF)

    var rawValue: CFString
    init(rawValue: CFString) {
        self.rawValue = rawValue
    }

    init?(mimeType: String) {
        guard let contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil)
        else {
            return nil
        }
        self.rawValue = contentType.takeRetainedValue()
    }

    init?(fileExtension: String) {
        guard let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension as CFString, nil)
        else {
            return nil
        }
        self.rawValue = uti.takeRetainedValue()
    }

}

extension UTType {

    var mimeType: String? {
        UTTypeCopyPreferredTagWithClass(self.rawValue, kUTTagClassMIMEType)?.takeRetainedValue() as String?
    }

    var fileExtension: String? {
        UTTypeCopyPreferredTagWithClass(self.rawValue, kUTTagClassFilenameExtension)?.takeRetainedValue() as String?
    }

    var description: String? {
        UTTypeCopyDescription(self.rawValue)?.takeRetainedValue() as String?
    }

    @available(OSX 11.0, *)
    private var utType: UniformTypeIdentifiers.UTType {
        UniformTypeIdentifiers.UTType(rawValue as String) ?? .plainText
    }

    var icon: NSImage {
        if #available(OSX 11.0, *) {
            return NSWorkspace.shared.icon(for: self.utType)
        } else {
            return NSWorkspace.shared.icon(forFileType: rawValue as String)
        }
    }

}
