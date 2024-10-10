//
//  FileDownloadManagerMock.swift
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

import Combine
import Foundation
import Navigation
import UniformTypeIdentifiers

@testable import DuckDuckGo_Privacy_Browser

final class FileDownloadManagerMock: FileDownloadManagerProtocol, WebKitDownloadTaskDelegate {

    var downloads = Set<WebKitDownloadTask>()

    var downloadAddedSubject = PassthroughSubject<WebKitDownloadTask, Never>()
    var downloadsPublisher: AnyPublisher<WebKitDownloadTask, Never> {
        downloadAddedSubject.eraseToAnyPublisher()
    }

    var addDownloadBlock: ((WebKitDownload,
                            DownloadTaskDelegate?,
                            WebKitDownloadTask.DownloadDestination) -> WebKitDownloadTask)?
    func add(_ download: any WebKitDownload, fireWindowSession: DuckDuckGo_Privacy_Browser.FireWindowSessionRef?, delegate: (any DuckDuckGo_Privacy_Browser.DownloadTaskDelegate)?, destination: DuckDuckGo_Privacy_Browser.WebKitDownloadTask.DownloadDestination) -> DuckDuckGo_Privacy_Browser.WebKitDownloadTask {
        addDownloadBlock!(download, delegate, destination)
    }

    var cancelAllBlock: ((Bool) -> Void)?
    func cancelAll(waitUntilDone: Bool) {
        cancelAllBlock?(waitUntilDone)
    }

    func fileDownloadTaskNeedsDestinationURL(_ task: DuckDuckGo_Privacy_Browser.WebKitDownloadTask, suggestedFilename: String, suggestedFileType: UTType?) async -> (URL?, UTType?) {
        (nil, nil)
    }

    var downloadTaskDidFinishSubject = PassthroughSubject<(WebKitDownloadTask, Result<Void, FileDownloadError>), Never>()
    func fileDownloadTask(_ task: WebKitDownloadTask, didFinishWith result: Result<Void, FileDownloadError>) {
        downloadTaskDidFinishSubject.send((task, result))
    }

}
