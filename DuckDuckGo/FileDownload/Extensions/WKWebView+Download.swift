//
//  WKWebView+Download.swift
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
import Navigation
import WebKit

extension WKWebView {

    func startDownload(_ request: URLRequest, completionHandler: @escaping (WebKitDownload) -> Void) {
#if APPSTORE
        startDownload(using: request, completionHandler: completionHandler)
#else
        if #available(macOS 11.3, *) {
            startDownload(using: request, completionHandler: completionHandler)
        } else if configuration.processPool.responds(to: #selector(WKProcessPool._downloadURLRequest(_:websiteDataStore:originatingWebView:))) {
            configuration.processPool.setDownloadDelegateIfNeeded(using: LegacyWebKitDownloadDelegate.init)
            let download = configuration.processPool._downloadURLRequest(request,
                                                                         websiteDataStore: self.configuration.websiteDataStore,
                                                                         originatingWebView: self)
            completionHandler(download)
        } else {
            assertionFailure("WKProcessPool does not respond to _downloadURLRequest:websiteDataStore:originatingWebView:")
        }
#endif
    }

    func resumeDownload(from resumeData: Data, to localURL: URL, completionHandler: @escaping (WebKitDownload) -> Void) throws {
#if APPSTORE
        resumeDownload(fromResumeData: resumeData, completionHandler: completionHandler)
#else
        try NSException.catch {
            if #available(macOS 11.3, *) {
                resumeDownload(fromResumeData: resumeData, completionHandler: completionHandler)
            } else if configuration.processPool.responds(to:
              #selector(WKProcessPool._resumeDownload(from:websiteDataStore:path:originatingWebView:))) {
                let download = configuration.processPool._resumeDownload(from: resumeData,
                                                                         websiteDataStore: self.configuration.websiteDataStore,
                                                                         path: localURL.path,
                                                                         originatingWebView: self)
                completionHandler(download)
            } else {
                assertionFailure("WKProcessPool does not respond to _resumeDownloadFromData:websiteDataStore:path:originatingWebView:")
            }
        }
#endif
    }

    var suggestedFilename: String? {
        guard let title = self.title?.replacingOccurrences(of: "[~#@*+%{}<>\\[\\]|\"\\_^\\/:\\\\]",
                                                           with: "_",
                                                           options: .regularExpression),
              !title.isEmpty
        else {
            return url?.suggestedFilename
        }
        return title.appending(".html")
    }

    enum ContentExportType {
        case html
        case pdf
        case webArchive

        init?(utType: UTType) {
            switch utType {
            case .html:
                self = .html
            case .webArchive:
                self = .webArchive
            case .pdf:
                self = .pdf
            default:
                return nil
            }
        }
    }

    func exportWebContent(to url: URL,
                          as exportType: ContentExportType,
                          completionHandler: ((Result<URL, Error>) -> Void)? = nil) {
        let create: (@escaping (Data?, Error?) -> Void) -> Void
        var transform: (Data) throws -> Data = { return $0 }

        switch exportType {
        case .webArchive:
            create = self.createWebArchiveData

        case .pdf:
            create = { self.createPDF(withConfiguration: nil, completionHandler: $0) }

        case .html:
            create = self.createWebArchiveData
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
        }

        let progress = Progress(totalUnitCount: 1,
                                fileOperationKind: .downloading,
                                kind: .file,
                                isPausable: false,
                                isCancellable: false,
                                fileURL: url)
        progress.publish()

        create { (data, error) in
            defer {
                progress.completedUnitCount = progress.totalUnitCount
                progress.unpublish()
            }
            do {
                if let error = error { throw error }
                guard let data = try data.map(transform) else { throw URLError(.cancelled) }

                try data.write(to: url)
                completionHandler?(.success(url))

            } catch {
                completionHandler?(.failure(error))
            }
        }
    }

}

protocol NavigationDownloadPolicy {
    static var download: Self { get }
}

extension NavigationActionPolicy: NavigationDownloadPolicy {}
extension NavigationResponsePolicy: NavigationDownloadPolicy {}

extension NavigationDownloadPolicy {

    static func download(_ url: URL, using webView: WKWebView, with callback: @escaping (WebKitDownload) -> Void) -> Self {
#if !APPSTORE
        webView.configuration.processPool
            .setDownloadDelegateIfNeeded(using: LegacyWebKitDownloadDelegate.init)?
            .registerDownloadDidStartCallback(callback, for: url)
#endif
        return .download
    }

}
