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
    
    func testWhenPassingAValidPathToTheTemporaryFileHandler_ThenTheFileIsCopied_AndDeletedAfterTheHandlerIsComplete() throws {
        let handler = TemporaryFileHandler(fileURL: loginDatabaseURL())
        let copiedFileURL = try handler.copyFileToTemporaryDirectory()
        
        XCTAssertTrue(copiedFileURL.path.contains(NSTemporaryDirectory()))
        XCTAssertTrue(FileManager.default.fileExists(atPath: copiedFileURL.path))
        XCTAssertEqual(copiedFileURL.pathExtension, "db")

        handler.deleteTemporarilyCopiedFile()
        
        XCTAssertFalse(FileManager.default.fileExists(atPath: copiedFileURL.path))
    }
    
    private func loginDatabaseURL() -> URL {
        let bundle = Bundle(for: TemporaryFileHandlerTests.self)
        return bundle.resourceURL!.appendingPathComponent("Data Import Resources/Test Firefox Data/No Primary Password/key4.db")
    }
    
}
