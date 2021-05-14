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
    case webContent(WKWebView)
    case data(Data, mimeType: String, suggestedName: String?, sourceURL: URL?)
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

    func downloadTask() -> FileDownloadTask? {
        switch self {
        case .request(let request, suggestedName: _):
            return URLRequestDownloadTask(download: self, session: nil, request: request)

        case .webContent(let webView):
            let contentType = (try? webView.evaluateSynchronously("document.contentType", timeout: 1.0) as? String)
                .flatMap(UTType.init(mimeType:)) ?? .html

            if case .html = contentType {
                return WebContentDownloadTask(download: self, webView: webView)

            } else if let url = webView.url, url.isFileURL == true {
                return LocalFileSaveTask(download: self, url: url, fileType: UTType(fileExtension: url.pathExtension))
            } else if let url = webView.url {
                return URLRequestDownloadTask(download: self, request: URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad))
            } else {
                return nil
            }

        case .data(let data, mimeType: let mimeType, suggestedName: let suggestedName, sourceURL: _):
            return DataSaveTask(download: self, data: data, mimeType: mimeType, suggestedFilename: suggestedName)
        }
    }

    var sourceURL: URL? {
        switch self {
        case .request(let request, suggestedName: _):
            return request.url
        case .webContent(let webView):
            return webView.url
        case .data(_, mimeType: _, suggestedName: _, sourceURL: let url):
            return url
        }
    }

}
