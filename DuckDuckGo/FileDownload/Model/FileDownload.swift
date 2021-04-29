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

struct FileDownload {
    enum DownloadKind {
        case request(URLRequest)
        case webContent(WKWebView, request: URLRequest?)
        case data(Data, mimeType: String)
    }

    let kind: DownloadKind
    let suggestedName: String?
    let window: NSWindow?
    let forceSaveLocationChooser: Bool

    init(url: URL, window: NSWindow?, forceSaveLocationChooser: Bool = false) {
        self.kind = .request(URLRequest(url: url))
        self.window = window
        self.forceSaveLocationChooser = forceSaveLocationChooser
        self.suggestedName = nil
    }

    init(request: URLRequest, suggestedName: String?, window: NSWindow?, forceSaveLocationChooser: Bool = false) {
        self.kind = .request(request)
        self.window = window
        self.forceSaveLocationChooser = forceSaveLocationChooser
        self.suggestedName = suggestedName
    }

    init(data: Data, mimeType: String, suggestedName: String?, window: NSWindow?, forceSaveLocationChooser: Bool = false) {
        self.kind = .data(data, mimeType: mimeType)
        self.window = window
        self.forceSaveLocationChooser = forceSaveLocationChooser
        self.suggestedName = suggestedName
    }

    init(webView: WKWebView, request: URLRequest?, window: NSWindow?, forceSaveLocationChooser: Bool) {
        self.kind = .webContent(webView, request: request)
        self.window = window
        self.forceSaveLocationChooser = forceSaveLocationChooser
        self.suggestedName = webView.title
    }

    func downloadTask() -> FileDownloadTask {
        switch kind {
        case .request(let request):
            return URLRequestDownloadTask(session: nil, request: request)

        case .webContent(let webView, request: let request):
            if let url = webView.url, url.isFileURL == true {
                return LocalFileSaveTask(url: url, fileType: UTType(fileExtension: url.pathExtension))
            }
            return WebContentDownloadTask(webView: webView, request: request)

        case .data(let data, mimeType: let mimeType):
            return DataSaveTask(data: data, mimeType: mimeType, suggestedFilename: suggestedName)
        }
    }

    var shouldAlwaysPromptFileSaveLocation: Bool {
        switch kind {
        case .webContent:
            return true
        case .request, .data:
            return false
        }
    }

}
