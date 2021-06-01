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

protocol FileDownloadRequest {
    var shouldAlwaysPromptFileSaveLocation: Bool { get }
    var sourceURL: URL? { get }
    func downloadTask() -> FileDownloadTask?
}

enum FileDownload: FileDownloadRequest {
    case request(URLRequest, suggestedName: String?, promptForLocation: Bool)
    case webContent(WKWebView, mimeType: String?)
    case wkDownload(WebKitDownload)
}

enum FileDownloadPostflight {
    case reveal
    case open
}

extension FileDownload {

    init(url: URL, promptForLocation: Bool) {
        self = .request(URLRequest(url: url), suggestedName: nil, promptForLocation: promptForLocation)
    }

    var shouldAlwaysPromptFileSaveLocation: Bool {
        switch self {
        case .webContent:
            return true
        case .request(_, suggestedName: _, promptForLocation: let promptForLocation):
            return promptForLocation
        case .wkDownload:
            return false
        }
    }

    func downloadTask() -> FileDownloadTask? {
        switch self {
        case .request(let request, suggestedName: _, promptForLocation: _):
            return URLRequestDownloadTask(download: self, session: nil, request: request)

        case .webContent(let webView, mimeType: let mimeType):
            let contentType = mimeType.flatMap(UTType.init(mimeType:))
            if case .html = (contentType ?? .html) {
                return WebContentDownloadTask(download: self, webView: webView)

            } else if let url = webView.url, url.isFileURL {
                return LocalFileSaveTask(download: self,
                                         url: url,
                                         fileType: contentType ?? UTType(fileExtension: url.pathExtension))
            } else if let url = webView.url {
                return URLRequestDownloadTask(download: self, request: URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad))
            } else {
                return nil
            }

        case .wkDownload(let download):
            return WebKitDownloadTask(download: download)
        }
    }

    var sourceURL: URL? {
        switch self {
        case .request(let request, suggestedName: _, promptForLocation: _):
            return request.url
        case .webContent(let webView, mimeType: _):
            return webView.url
        case .wkDownload(let download):
            return download.request?.url
        }
    }

}
