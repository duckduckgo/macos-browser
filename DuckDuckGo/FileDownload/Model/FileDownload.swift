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
import WebKit

enum FileDownload {
    case request(URLRequest, suggestedName: String?)
    case webContent(WKWebView, request: URLRequest?)
    case data(Data, mimeType: String, suggestedName: String?)
}

extension FileDownload {

    init(url: URL) {
        self = .request(URLRequest(url: url), suggestedName: nil)
    }

    var shouldAlwaysPromptFileSaveLocation: Bool {
        switch self {
        case .webContent:
            return true
        case .request, .data:
            return false
        }
    }

    var suggestedName: String? {
        switch self {
        case .request(let request, suggestedName: let suggestedName):
            return suggestedName
        case .webContent(let webView, request: _):
            return webView.title
        case .data(_, mimeType: _, suggestedName: let suggestedName):
            return suggestedName
        }
    }

    func downloadTask() -> FileDownloadTask {
        switch self {
        case .request(let request, suggestedName: _):
            return URLRequestDownloadTask(download: self, session: nil, request: request)

        case .webContent(let webView, request: let request):
            if let url = webView.url, url.isFileURL == true {
                return LocalFileSaveTask(download: self, url: url, fileType: UTType(fileExtension: url.pathExtension))
            }
            return WebContentDownloadTask(download: self, webView: webView, request: request)

        case .data(let data, mimeType: let mimeType, suggestedName: let suggestedName):
            return DataSaveTask(download: self, data: data, mimeType: mimeType, suggestedFilename: suggestedName)
        }
    }

}
