//
//  FileDownloadTaskDelegateMock.swift
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
@testable import DuckDuckGo_Privacy_Browser

final class FileDownloadTaskDelegateMock: FileDownloadTaskDelegate {
    var destinationURLCallback: ((FileDownloadTask, @escaping (URL?, UTType?) -> Void) -> Void)?
    var downloadDidFinish: ((FileDownloadTask, Result<URL, FileDownloadError>) -> Void)?

    func fileDownloadTaskNeedsDestinationURL(_ task: FileDownloadTask, completionHandler: @escaping (URL?, UTType?) -> Void) {
        destinationURLCallback?(task, completionHandler)
    }

    func fileDownloadTask(_ task: FileDownloadTask, didFinishWith result: Result<URL, FileDownloadError>) {
        downloadDidFinish?(task, result)
    }
}
