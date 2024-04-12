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
import UniformTypeIdentifiers
import WebKit

extension WKWebView {

    var suggestedFilename: String? {
        guard let title = self.title?.replacingInvalidFileNameCharacters(), !title.isEmpty else {
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
        let create: (@escaping (Result<Data, Error>) -> Void) -> Void
        var transform: (Data) -> Data? = { return $0 }

        switch exportType {
        case .webArchive:
            create = self.createWebArchiveData

        case .pdf:
            create = { self.createPDF(completionHandler: $0) }

        case .html:
            create = self.createWebArchiveData
            transform = { data in
                // extract HTML from WebArchive bplist
                let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
                let mainResource = dict?["WebMainResource"] as? [String: Any]
                return mainResource?["WebResourceData"] as? Data
            }
        }

        let progress = Progress(totalUnitCount: 1,
                                fileOperationKind: .downloading,
                                kind: .file,
                                isPausable: false,
                                isCancellable: false,
                                fileURL: url)
        progress.publish()

        create { (result) in
            defer {
                progress.completedUnitCount = progress.totalUnitCount
                progress.unpublish()
            }
            do {
                let data = try result.map(transform).get() ?? { throw URLError(.cancelled) }()
                try data.write(to: url)
                completionHandler?(.success(url))
            } catch {
                completionHandler?(.failure(error))
            }
        }
    }

}
