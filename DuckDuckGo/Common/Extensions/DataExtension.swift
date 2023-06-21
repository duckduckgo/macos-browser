//
//  DataExtension.swift
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

extension Data {

    func utf8String() -> String? {
        return String(data: self, encoding: .utf8)
    }

    /**
        Writes this data to the specified URL as though it was a file showing progress.  Primarily this is used to show a bounce if the file is in a location on the user's dock (e.g. Downloads).
     */
    func writeFileWithProgress(to url: URL) throws {
        let progress = Progress(totalUnitCount: 1,
                                fileOperationKind: .downloading,
                                kind: .file,
                                isPausable: false,
                                isCancellable: false,
                                fileURL: url)

        progress.publish()
        defer {
            progress.unpublish()
        }

        try self.write(to: url)
        progress.completedUnitCount = progress.totalUnitCount
    }

}
