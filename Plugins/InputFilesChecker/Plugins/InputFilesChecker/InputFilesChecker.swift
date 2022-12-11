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
import PackagePlugin
import XcodeProjectPlugin

let extraInputFiles: [TargetName: Set<InputFile>] = [
    "DuckDuckGo Privacy Browser": [
        .init("BWEncryption.m", .source),
        .init("BWEncryptionOutput.m", .source),
        .init("BWManager.swift", .source),
        .init("UpdateController.swift", .source)
    ],

    "Unit Tests": [
        .init("BWEncryptionTests.swift", .source)
    ]
]

typealias TargetName = String

struct InputFileDiff {
    var extra: Set<InputFile>
    var missing: Set<InputFile>

    init(extra: Set<InputFile> = [], missing: Set<InputFile> = []) {
        self.extra = extra
        self.missing = missing
    }
}

public struct InputFile: Hashable {
    public var fileName: String
    public var type: FileType

    public init(_ fileName: String, _ type: FileType) {
        self.fileName = fileName
        self.type = type
    }

    public init(_ file: File) {
        self.fileName = file.path.lastComponent
        self.type = file.type
    }
}

@main
struct TargetSourcesChecker: BuildToolPlugin, XcodeBuildToolPlugin {
    func createBuildCommands(context: PackagePlugin.PluginContext, target: PackagePlugin.Target) async throws -> [PackagePlugin.Command] {
        return []
    }

    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        var appTargets: [XcodeTarget] = []
        var unitTestsTargets: [XcodeTarget] = []
        var integrationTestsTargets: [XcodeTarget] = []

        context.xcodeProject.targets.forEach { target in
            switch target.product?.kind {
            case .application:
                appTargets.append(target)
            case .other("com.apple.product-type.bundle.unit-test"):
                if target.displayName.starts(with: "Unit Tests") {
                    unitTestsTargets.append(target)
                } else if target.displayName.starts(with: "Integration Tests") {
                    integrationTestsTargets.append(target)
                }
            default:
                break
            }
        }

        if appTargets.isEmpty || unitTestsTargets.isEmpty || integrationTestsTargets.isEmpty {
            throw NoTargetsFoundError()
        }

        try check(appTargets)
        try check(unitTestsTargets)
        try check(integrationTestsTargets)

        return []
    }

    private func check(_ targets: [XcodeTarget]) throws {
        if targets.isEmpty {
            return
        }

        var commonInputFiles: Set<InputFile> = Set(targets[0].inputFiles.map(InputFile.init))
        for target in targets[1..<targets.count] {
            commonInputFiles.formIntersection(target.inputFiles.map(InputFile.init))
        }

        for target in targets {
            let inputFiles = Set(target.inputFiles.map(InputFile.init))
            let extraFiles = inputFiles.subtracting(commonInputFiles)

            let expectedExtraFiles = extraInputFiles[target.displayName] ?? []

            if expectedExtraFiles != extraFiles {
                throw ExtraFilesError(target: target.displayName, actual: extraFiles, expected: expectedExtraFiles)
            }
        }
    }
}

extension File: Equatable, Hashable {
    public static func == (lhs: File, rhs: File) -> Bool {
        lhs.path == rhs.path && lhs.type == rhs.type
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(path)
        hasher.combine(type)
    }
}
