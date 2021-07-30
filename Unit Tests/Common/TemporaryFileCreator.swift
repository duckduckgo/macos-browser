//
//  TemporaryFileCreator.swift
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
import XCTest

final class TemporaryFileCreator {

    var createdFileNames: [String] = []

    func persist(fileContents: Data, named fileName: String) -> URL? {
        let fileURL = temporaryURL(fileName: fileName)

        do {
            try fileContents.write(to: fileURL)
            createdFileNames.append(fileName)

            return fileURL
        } catch {
            XCTFail("\(#file): Failed to persist temporary file named '\(fileName)'")
        }

        return nil
    }

    func deleteCreatedTemporaryFiles() {
        for fileName in createdFileNames {
            let fileURL = temporaryURL(fileName: fileName)
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private func temporaryURL(fileName: String) -> URL {
        let temporaryURL = FileManager.default.temporaryDirectory
        return temporaryURL.appendingPathComponent(fileName)
    }

}
