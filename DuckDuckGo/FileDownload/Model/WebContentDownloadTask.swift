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

    override var suggestedFilename: String {
        guard let title = webView.title?.replacingOccurrences(of: "[~#@*+%{}<>\\[\\]|\"\\_^\\/:]",
                                                              with: "_",
                                                              options: .regularExpression),
              !title.isEmpty
        else {
            return super.suggestedFilename
        }
        return title
    }

    private var subTask: FileDownloadTask?
    private var localURL: URL?

    init(download: FileDownloadRequest, webView: WKWebView) {
        self.webView = webView
        super.init(download: download)
        self.fileTypes = [.html, .webArchive, .pdf]
    }

    override func localFileURLCompletionHandler(localURL: URL?, fileType: UTType?) {
        guard let localURL = localURL else {
            self.finish(with: .failure(.cancelled))
            return
        }
        self.localURL = localURL
        let fileType = fileType ?? UTType(fileExtension: localURL.pathExtension)

        let create: (@escaping (Data?, Error?) -> Void) -> Void
        var transform: (Data) throws -> Data = { return $0 }

        switch fileType {
        case .some(.webArchive):
            create = self.webView.createWebArchiveData

        case .some(.pdf):
            create = { self.webView.createPDF(withConfiguration: nil, completionHandler: $0) }

        case .some(.html):
            create = self.webView.createWebArchiveData
            transform = { data in
                // extract HTML from WebArchive bplist
                guard let dict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                      let mainResource = dict["WebMainResource"] as? [String: Any],
                      let resourceData = mainResource["WebResourceData"] as? NSData
                else {
                    struct GetWebResourceDataFromWebArchiveData: Error { let data: Data }
                    throw GetWebResourceDataFromWebArchiveData(data: data)
                }

                return resourceData as Data
            }

        default:
            assertionFailure("WebContentDownloadTask.localFileURLCompletionHandler unexpected file type \(fileType?.fileExtension ?? "<nil>")")
            self.finish(with: .failure(.cancelled))
            return
        }

        create { (data, error) in
            do {
                if let error = error { throw error }
                guard let data = try data.map(transform) else { throw FileDownloadError.cancelled }

                let saveTask = DataSaveTask(download: self.download, data: data)
                self.subTask = saveTask
                saveTask.progress.flyToImage = self.progress.flyToImage
                saveTask.progress.fileIconOriginalRect = self.progress.fileIconOriginalRect
                saveTask.start(delegate: self)

            } catch {
                self.finish(with: .failure(.failedToCompleteDownloadTask(underlyingError: error)))
            }
        }
    }

}

extension WebContentDownloadTask: FileDownloadTaskDelegate {

    func fileDownloadTaskNeedsDestinationURL(_ task: FileDownloadTask, completionHandler: @escaping (URL?, UTType?) -> Void) {
        completionHandler(localURL, nil)
    }

    func fileDownloadTask(_ task: FileDownloadTask, didFinishWith result: Result<URL, FileDownloadError>) {
        self.finish(with: result)
    }

}
