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
    static let html = {
        if #available(macOS 11.0, *) {
            return UTType(rawValue: UniformTypeIdentifiers.UTType.html.identifier as CFString)
        } else {
            return UTType(rawValue: kUTTypeHTML)
        }
    }()

    static let webArchive = {
        if #available(macOS 11.0, *) {
            return UTType(rawValue: UniformTypeIdentifiers.UTType.webArchive.identifier as CFString)
        } else {
            return UTType(rawValue: kUTTypeWebArchive)
        }
    }()

    static let pdf = {
        if #available(macOS 11.0, *) {
            return UTType(rawValue: UniformTypeIdentifiers.UTType.pdf.identifier as CFString)
        } else {
            return UTType(rawValue: kUTTypePDF)
        }
    }()

    static let jpeg = {
        if #available(macOS 11.0, *) {
            return UTType(rawValue: UniformTypeIdentifiers.UTType.jpeg.identifier as CFString)
        } else {
            return UTType(rawValue: kUTTypeJPEG)
        }
    }()

    static let data = {
        if #available(macOS 11.0, *) {
            return UTType(rawValue: UniformTypeIdentifiers.UTType.data.identifier as CFString)
        } else {
            return UTType(rawValue: kUTTypeData)
        }
    }()

    static let text = {
        if let utType = UTType(fileExtension: "txt") { return utType }
        if #available(macOS 11.0, *) {
            return UTType(rawValue: UniformTypeIdentifiers.UTType.text.identifier as CFString)
        } else {
            return UTType(rawValue: kUTTypeText)
        }
    }()

    static let log = {
        if let utType = UTType(fileExtension: "log") { return utType }
        if #available(macOS 11.0, *) {
            return UTType(rawValue: UniformTypeIdentifiers.UTType.log.identifier as CFString)
        } else {
            return UTType(rawValue: kUTTypeLog)
        }
    }()

    var rawValue: CFString
    init(rawValue: CFString) {
        self.rawValue = rawValue
    }

    init?(mimeType: String) {
        let contentType: CFString? = {
            if #available(macOS 11.0, *) {
                return UniformTypeIdentifiers.UTType(mimeType: mimeType)?.identifier as CFString?
            } else {
                return UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil)?.takeRetainedValue()
            }
        }()
        guard let contentType else {
            return nil
        }
        self.rawValue = contentType
    }

    init?(fileExtension: String) {
        let uti: CFString? = {
            if #available(macOS 11.0, *) {
                return UniformTypeIdentifiers.UTType(filenameExtension: fileExtension)?.identifier as CFString?
            } else {
                return UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension as CFString, nil)?.takeRetainedValue()
            }
        }()
        guard let uti else {
            return nil
        }
        self.rawValue = uti
    }

}

extension UTType {

    var mimeType: String? {
        if #available(macOS 11.0, *) {
            return UniformTypeIdentifiers.UTType(rawValue as String)?.preferredMIMEType
        } else {
            return UTTypeCopyPreferredTagWithClass(rawValue, kUTTagClassMIMEType)?.takeRetainedValue() as String?
        }
    }

    var fileExtension: String? {
        if #available(macOS 11.0, *) {
            return UniformTypeIdentifiers.UTType(rawValue as String)?.preferredFilenameExtension
        } else {
            return UTTypeCopyPreferredTagWithClass(rawValue, kUTTagClassFilenameExtension)?.takeRetainedValue() as String?
        }
    }

    var description: String? {
        if #available(macOS 11.0, *) {
            return UniformTypeIdentifiers.UTType(rawValue as String)?.localizedDescription
        } else {
            return UTTypeCopyDescription(rawValue)?.takeRetainedValue() as String?
        }
    }

    @available(OSX 11.0, *)
    private var utType: UniformTypeIdentifiers.UTType {
        UniformTypeIdentifiers.UTType(rawValue as String) ?? .plainText
    }

    var icon: NSImage {
        guard #available(OSX 11.0, *) else {
            return NSWorkspace.shared.icon(forFileType: rawValue as String)
        }
        return NSWorkspace.shared.icon(for: self.utType)
    }

}
