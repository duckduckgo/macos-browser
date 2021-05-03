//
//  WebContentDownloadTask.swift
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
import WebKit

final class WebContentDownloadTask: FileDownloadTask {

    let webView: WKWebView
    let request: URLRequest?

    override var suggestedFilename: String? {
        get {
            webView.title?.replacingOccurrences(of: "[~#@*+%{}<>\\[\\]|\"\\_^\\/:]", with: "_", options: .regularExpression)
        }
        set { }
    }

    override var fileTypes: [UTType]? {
        get {
            if #available(OSX 11.0, *) {
                return [.html, .webArchive]
            } else {
                return [.html]
            }
        }
        set { }
    }

    private var subTask: FileDownloadTask?
    private var localURL: URL?

    init(download: FileDownload, webView: WKWebView, request: URLRequest?) {
        self.webView = webView
        self.request = request

        super.init(download: download)
    }

    override func start(delegate: FileDownloadTaskDelegate) {
        super.start(delegate: delegate)
        delegate.fileDownloadTaskNeedsDestinationURL(self, completionHandler: self.localFileURLCompletionHandler)
    }

    private func localFileURLCompletionHandler(_ localURL: URL?) {
        guard let localURL = localURL else {
            delegate?.fileDownloadTask(self, didFinishWith: .failure(.cancelled))
            return
        }
        self.localURL = localURL

        if #available(OSX 11.0, *),
           case .some(.webArchive) = UTType(fileExtension: localURL.pathExtension) {
            self.webView.createWebArchiveData { result in
                switch result {
                case .success(let data):
                    self.subTask = DataSaveTask(download: self.download, data: data)
                    self.subTask!.start(delegate: self)

                case .failure(let error):
                    self.delegate?.fileDownloadTask(self, didFinishWith: .failure(.failedToCompleteDownloadTask(underlyingError: error)))
                }
            }

        } else if let request = self.request
                    ?? self.webView.url.map({ URLRequest(url: $0, cachePolicy: .returnCacheDataElseLoad) }) {

            self.subTask = URLRequestDownloadTask(download: self.download, request: request)
            self.subTask!.start(delegate: self)

        } else {
            self.delegate?.fileDownloadTask(self, didFinishWith: .failure(.cancelled))
        }
    }

}

extension WebContentDownloadTask: FileDownloadTaskDelegate {

    func fileDownloadTaskNeedsDestinationURL(_ task: FileDownloadTask, completionHandler: @escaping (URL?) -> Void) {
        completionHandler(localURL)
    }

    func fileDownloadTask(_ task: FileDownloadTask, didFinishWith result: Result<URL, FileDownloadError>) {
        self.delegate?.fileDownloadTask(self, didFinishWith: result)
    }

}
