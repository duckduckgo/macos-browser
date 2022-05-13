//
//  TemporaryFileHandlerTests.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import XCTest
import Combine
@testable import DuckDuckGo_Privacy_Browser

final class TemporaryFileHandlerTests: XCTestCase {
    
    func testWhenPassingAValidPathToTheTemporaryFileHandler_ThenTheFileIsCopied_AndDeletedAfterTheHandlerIsComplete() {
        let handler = TemporaryFileHandler(fileURL: loginDatabaseURL())
        let result = handler.copyFileToTemporaryDirectory()
        
        var copiedFileURL: URL?
        
        switch result {
        case .success(let url):
            XCTAssertTrue(url.path.contains(NSTemporaryDirectory()))
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            XCTAssertEqual(url.pathExtension, "db")
            copiedFileURL = url
        case .failure(let error):
            XCTFail("Failed to copy file to temporary directory, with error: \(error.localizedDescription)")
        }

        handler.deleteTemporarilyCopiedFile()
        
        // Verify that the file has since been deleted.
        if let copiedFileURL = copiedFileURL {
            XCTAssertFalse(FileManager.default.fileExists(atPath: copiedFileURL.path))
        } else {
            XCTFail("Didn't get copied file URL")
        }
    }
    
    private func loginDatabaseURL() -> URL {
        let bundle = Bundle(for: TemporaryFileHandlerTests.self)
        return bundle.resourceURL!.appendingPathComponent("Data Import Resources/Test Firefox Data/No Primary Password/key4.db")
    }
    
}
