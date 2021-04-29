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

    var suggestedFilename: String? {
        webView.title?.replacingOccurrences(of: "[~#@*+%{}<>\\[\\]|\"\\_^\\/:]", with: "_", options: .regularExpression)
    }

    var fileTypes: [UTType]? {
        if #available(OSX 11.0, *) {
            return [.html, .webArchive]
        } else {
            return [.html]
        }
    }

    init(webView: WKWebView, request: URLRequest?) {
        self.webView = webView
        self.request = request
    }

    func start(localFileURLCallback: @escaping LocalFileURLCallback, completion: @escaping (Result<URL, FileDownloadError>) -> Void) {

        localFileURLCallback(self) { url in
            guard let localURL = url else {
                completion(.failure(.cancelled))
                return
            }

            if #available(OSX 11.0, *),
               case .some(.webArchive) = UTType(fileExtension: localURL.pathExtension) {
                self.webView.createWebArchiveData { result in
                    switch result {
                    case .success(let data):
                        let saveTask = DataSaveTask(data: data)
                        saveTask.start(localFileURLCallback: { $1(localURL) }) { result in
                            withExtendedLifetime(saveTask) {
                                completion(result)
                            }
                        }
                    case .failure(let error):
                        completion(.failure(.failedToCompleteDownloadTask(underlyingError: error)))
                    }
                }

            } else if let request = self.request
                        ?? self.webView.url.map({ URLRequest(url: $0, cachePolicy: .returnCacheDataElseLoad) }) {
                
                let downloadTask = URLRequestDownloadTask(request: request)
                downloadTask.start(localFileURLCallback: { $1(localURL) }) { result in
                    withExtendedLifetime(downloadTask) {
                        completion(result)
                    }
                }

            } else {
                completion(.failure(.cancelled))
            }
        }
    }

}
