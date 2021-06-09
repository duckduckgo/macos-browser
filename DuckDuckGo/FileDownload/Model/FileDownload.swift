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
    case webContent(WKWebView, mimeType: String?)
    case wkDownload(WebKitDownload, promptForLocation: Bool)
}

enum FileDownloadPostflight {
    case reveal
    case open
}

extension FileDownload {

    var shouldAlwaysPromptFileSaveLocation: Bool {
        switch self {
        case .webContent:
            return true
        case .wkDownload(_, promptForLocation: let promptForLocation):
            return promptForLocation
        }
    }

    func downloadTask() -> FileDownloadTask? {
        switch self {
        case .webContent(let webView, mimeType: let mimeType):
            let contentType = mimeType.flatMap(UTType.init(mimeType:)) ?? .html
            return WebContentDownloadTask(download: self, webView: webView, contentType: contentType)

        case .wkDownload(let download, promptForLocation: let promptForLocation):
            return WebKitDownloadTask(download: download, promptForLocation: promptForLocation)
        }
    }

    var sourceURL: URL? {
        switch self {
        case .webContent(let webView, mimeType: _):
            return webView.url
        case .wkDownload(let download, promptForLocation: _):
            return download.downloadRequest?.url
        }
    }

}
