//
//  FileDownloadTests.swift
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
import XCTest
import Combine
@testable import DuckDuckGo_Privacy_Browser

final class FileDownloadTests: XCTestCase {

    let requestWithFileName = URLRequest(url: URL(string: "https://www.example.com/file.html")!)
    let requestWithPath = URLRequest(url: URL(string: "https://www.example.com/")!)
    let requestWithLongerPath = URLRequest(url: URL(string: "https://www.example.com/Guitar")!)

    func testWhenPathAvailableThenCombineWithMimeTypeForBestName() {
        let download = FileDownload.request(requestWithLongerPath, suggestedName: nil)
        XCTAssertEqual("Guitar", download.downloadTask()?.suggestedFilename)
    }

    func testWhenFileTypeMatchesThenNoExtensionDuplicationOccurs() {
        let download = FileDownload.request(requestWithFileName, suggestedName: nil)
        XCTAssertEqual("file.html", download.downloadTask()?.suggestedFilename)
    }

    func testWhenSuggestedNameNotPresentAndURLHasFileNameThenFileNameIsBest() {
        let download = FileDownload.request(requestWithFileName, suggestedName: nil)
        XCTAssertEqual("file.html", download.downloadTask()?.suggestedFilename)
    }

}
