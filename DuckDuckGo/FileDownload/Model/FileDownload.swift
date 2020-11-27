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

    func bestFileName(fileType: String?) -> String {
        return suggestedName ??
            fileNameFromURL(fileType: fileType) ??
            createUniqueFileName(fileType: fileType)
    }

    func createUniqueFileName(fileType: String?) -> String {
        let suffix: String
        if let fileType = fileType {
            suffix = "." + fileType
        } else {
            suffix = ""
        }

        let prefix: String
        if let host = request.url?.host?.drop(prefix: "www.") {
            prefix = host + "_"
        } else {
            prefix = ""
        }

        return prefix + UUID().uuidString + suffix
    }

    /// Tries to use the file name part of the URL, if available, adjusting for content type, if available.
    func fileNameFromURL(fileType: String?) -> String? {
        guard let url = request.url, !url.pathExtension.isEmpty else { return nil }
        let suffix: String
        if let fileType = fileType,
           !url.lastPathComponent.hasSuffix("." + fileType) {
            suffix = "." + fileType
        } else {
            suffix = ""
        }

        return url.lastPathComponent + suffix
    }

}
