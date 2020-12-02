//
//  FileDownload.swift
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

struct FileDownload {

    var request: URLRequest
    var suggestedName: String?

    /// Based on Content-Length header, if avialable.
    var contentLength: Int? {
        guard let contentLength = request.allHTTPHeaderFields?["Content-Length"] else { return nil }
        return Int(contentLength)
    }

    func bestFileName(mimeType: String?) -> String {
        return suggestedName ??
            fileNameFromURL(mimeType: mimeType) ??
            createUniqueFileName(mimeType: mimeType)
    }

    func createUniqueFileName(mimeType: String?) -> String {

        let suffix: String
        if let mimeType = mimeType, let ext = mimeToFileExtension(mimeType) {
            suffix = "." + ext
        } else {
            suffix = ""
        }

        let prefix: String
        if let host = request.url?.host?.drop(prefix: "www.").replacingOccurrences(of: ".", with: "_") {
            prefix = host + "_"
        } else {
            prefix = ""
        }

        return prefix + UUID().uuidString + suffix
    }

    /// Tries to use the file name part of the URL, if available, adjusting for content type, if available.
    func fileNameFromURL(mimeType: String?) -> String? {
        guard let url = request.url,
              !url.pathComponents.isEmpty,
              url.pathComponents != [ "/" ] else { return nil }

        if let mimeType = mimeType,
           hasMatchingMimeType(mimeType, extension: url.pathExtension) {
            // Mime-type and extensio match so go with it
            return url.lastPathComponent
        }

        if  let mimeType = mimeType,
            let ext = mimeToFileExtension(mimeType) {
            // there is a more appropriate extension, so use it
            return url.lastPathComponent + "." + ext
        }

        return url.lastPathComponent
    }

    func hasMatchingMimeType(_ mimeType: String, extension ext: String) -> Bool {
        return mimeToFileExtension(mimeType) == ext
    }

    func mimeToUti(_ mimeType: String) -> String? {
        guard let contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil) else { return nil }
        return contentType.takeRetainedValue() as String
    }

    func utiToFileExtension(_ utiType: String) -> String? {
        guard let ext = UTTypeCopyPreferredTagWithClass(utiType as CFString, kUTTagClassFilenameExtension) else { return nil }
        return ext.takeRetainedValue() as String
    }

    func mimeToFileExtension(_ mimeType: String) -> String? {
        guard let uti = mimeToUti(mimeType) else { return nil }
        return utiToFileExtension(uti)
    }

}
