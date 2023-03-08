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

import Navigation
import Foundation
import Combine
@testable import DuckDuckGo_Privacy_Browser

final class FileDownloadManagerMock: FileDownloadManagerProtocol {

    var downloads = Set<WebKitDownloadTask>()

    var downloadAddedSubject = PassthroughSubject<WebKitDownloadTask, Never>()
    var downloadsPublisher: AnyPublisher<WebKitDownloadTask, Never> {
        downloadAddedSubject.eraseToAnyPublisher()
    }

    var addDownloadBlock: ((WebKitDownload,
                            DownloadTaskDelegate?,
                            FileDownloadManager.DownloadLocationPreference) -> WebKitDownloadTask)?
    func add(_ download: WebKitDownload,
             delegate: DownloadTaskDelegate?,
             location: FileDownloadManager.DownloadLocationPreference) -> WebKitDownloadTask {
        addDownloadBlock!(download, delegate, location)
    }

    var cancelAllBlock: ((Bool) -> Void)?
    func cancelAll(waitUntilDone: Bool) {
        cancelAllBlock?(waitUntilDone)
    }

}
