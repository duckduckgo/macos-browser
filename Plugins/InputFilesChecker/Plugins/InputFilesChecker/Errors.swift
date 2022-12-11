//
//  TargetSourcesChecker.swift
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

import Foundation

struct NoTargetsFoundError: Error {}

struct ExtraFilesInconsistencyError: Error {
    var target: String
    var unexpected: [InputFile]
    var superfluous: [InputFile]
    var unrelated: [InputFile]

    init(target: String, actual: Set<InputFile>, expected: Set<InputFile>, unrelated: Set<InputFile>) {
        self.target = target
        self.unexpected = actual.subtracting(expected).sorted()
        self.superfluous = expected.subtracting(actual).subtracting(unrelated).sorted()
        self.unrelated = unrelated.sorted()
    }

    var localizedDescription: String {
        var description = [String]()
        if !unexpected.isEmpty {
            description.append("""
            \(target) includes files not present in other app targets:
            \(unexpected.map({ "* \($0.fileName)" }).joined(separator: "\n"))
            If this is expected, add these files to extraInputFiles in InputFilesChecker.swift.
            """)
        }
        if !superfluous.isEmpty {
            description.append("""
            \(target) includes files that are included by all app targets:
            \(superfluous.map({ "* \($0.fileName)" }).joined(separator: "\n"))
            Remove these files from extraInputFiles in InputFilesChecker.swift.
            """)
        }
        if !unrelated.isEmpty {
            description.append("""
            \(target) does not include files that are specified in extraInputFiles:
            \(unrelated.map({ "* \($0.fileName)" }).joined(separator: "\n"))
            Remove these files from extraInputFiles in InputFilesChecker.swift.
            """)
        }
        return description.joined(separator: "\n\n")
    }
}
