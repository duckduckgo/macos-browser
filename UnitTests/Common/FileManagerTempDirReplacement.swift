//
//  FileManagerTempDirReplacement.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

extension FileManager {

    static var swizzleTemporaryDirectoryOnce: Void = {
        let temporaryDirectoryMethod = class_getInstanceMethod(FileManager.self, #selector(getter: FileManager.temporaryDirectory))!
        let swizzledTemporaryDirectoryMethod = class_getInstanceMethod(FileManager.self, #selector(FileManager.swizzled_temporaryDirectory))!

        method_exchangeImplementations(temporaryDirectoryMethod, swizzledTemporaryDirectoryMethod)
    }()

    @objc dynamic func swizzled_temporaryDirectory() -> URL {
        let testsTempDir = self.swizzled_temporaryDirectory()
            .appendingPathComponent(Bundle(for: TestRunHelper.self).bundleIdentifier!)
        try? self.createDirectory(at: testsTempDir, withIntermediateDirectories: false)
        return testsTempDir
    }

    func cleanupTemporaryDirectory(excluding: Set<String> = []) {
        if excluding.isEmpty {
            try? self.removeItem(at: self.temporaryDirectory)
        } else {
            let temporaryDirectory = self.temporaryDirectory
            for file in (try? self.contentsOfDirectory(atPath: self.temporaryDirectory.path)) ?? [] where !excluding.contains(file) {
                try? self.removeItem(at: temporaryDirectory.appendingPathComponent(file))
            }
        }

        _=self.temporaryDirectory
    }

}
