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

    static let html = UTType(rawValue: UniformTypeIdentifiers.UTType.html.identifier as CFString)

    static let webArchive = UTType(rawValue: UniformTypeIdentifiers.UTType.webArchive.identifier as CFString)

    static let pdf = UTType(rawValue: UniformTypeIdentifiers.UTType.pdf.identifier as CFString)

    static let jpeg = UTType(rawValue: UniformTypeIdentifiers.UTType.jpeg.identifier as CFString)

    static let data = UTType(rawValue: UniformTypeIdentifiers.UTType.data.identifier as CFString)

    static let text = {
        if let utType = UTType(fileExtension: "txt") {
            return utType
        } else {
            return UTType(rawValue: UniformTypeIdentifiers.UTType.text.identifier as CFString)
        }
    }()

    static let log = {
        if let utType = UTType(fileExtension: "log") {
            return utType
        } else {
            return UTType(rawValue: UniformTypeIdentifiers.UTType.log.identifier as CFString)
        }
    }()

    var rawValue: CFString
    init(rawValue: CFString) {
        self.rawValue = rawValue
    }

    init?(mimeType: String) {
        guard let contentType = UniformTypeIdentifiers.UTType(mimeType: mimeType)?.identifier as CFString? else {
            return nil
        }
        self.rawValue = contentType
    }

    init?(fileExtension: String) {
        guard let uti = UniformTypeIdentifiers.UTType(filenameExtension: fileExtension)?.identifier as CFString? else {
            return nil
        }
        self.rawValue = uti
    }

}

extension UTType {

    var mimeType: String? {
        UniformTypeIdentifiers.UTType(rawValue as String)?.preferredMIMEType
    }

    var fileExtension: String? {
        UniformTypeIdentifiers.UTType(rawValue as String)?.preferredFilenameExtension
    }

    var description: String? {
        UniformTypeIdentifiers.UTType(rawValue as String)?.localizedDescription
    }

    private var utType: UniformTypeIdentifiers.UTType {
        UniformTypeIdentifiers.UTType(rawValue as String) ?? .plainText
    }

    var icon: NSImage {
        return NSWorkspace.shared.icon(for: self.utType)
    }

}
