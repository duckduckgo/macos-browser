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

/**
 * This dictionary keeps track of input files that are not present in all targets.
 *
 * By default, we expect all input files to be added to all app targets or tests targets.
 * If this is not the case, exceptions should be listed here.
 *
 * Add here files that are not included in all app targets or all unit tests targets.
 * This dictionary is checked at every build and if there are files not listed there, that
 * were otherwise not included in all app/test targets, the build will stop with an error.
 */
let extraInputFiles: [TargetName: Set<InputFile>] = [
    "DuckDuckGo Privacy Browser": [
        .init("BWEncryption.m", .source),
        .init("BWEncryptionOutput.m", .source),
        .init("BWManager.swift", .source),
        .init("UpdateController.swift", .source),
        .init("LegacyWebKitDownloadDelegate.swift", .source),
        .init("WKProcessPool+DownloadDelegate.swift", .source),
        .init("_WKDownload+WebKitDownload.swift", .source),
        .init("SystemExtensionManager.swift", .source),
        .init("DuckDuckGo Agent.app", .unknown),
        .init("DuckDuckGo Notifications.app", .unknown),
        .init("startVPN.app", .unknown),
        .init("stopVPN.app", .unknown),
        .init("PFMoveApplication.m", .source),
        .init("PurchaseManager.swift", .source),
        .init("PurchaseView.swift", .source),
        .init("PurchaseModel.swift", .source),
        .init("PurchaseViewController.swift", .source)
    ],

    "DuckDuckGo Privacy Browser App Store": [],

    "Unit Tests": [
        .init("BWEncryptionTests.swift", .source),
        .init("WKWebViewPrivateMethodsAvailabilityTests.swift", .source)
    ],

    "Integration Tests": []
]

typealias TargetName = String

struct InputFile: Hashable, Comparable {
    static func < (lhs: InputFile, rhs: InputFile) -> Bool {
        lhs.fileName < rhs.fileName
    }

    var fileName: String
    var type: FileType

    init(_ fileName: String, _ type: FileType) {
        self.fileName = fileName
        self.type = type
    }

    init(_ file: File) {
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
            case .application where target.displayName.starts(with: "DuckDuckGo Privacy Browser"):
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

        var errors = [Error]()
        for targets in [appTargets, unitTestsTargets, integrationTestsTargets] {
            do {
                try check(targets)
            } catch {
                errors.append(error)
            }
        }
        try CombinedError(errors: errors).throwIfNonEmpty()

        return []
    }

    private func check(_ targets: [XcodeTarget]) throws {
        if targets.isEmpty {
            return
        }

        var commonInputFiles: Set<InputFile> = Set(targets[0].inputFiles.map(InputFile.init))
        for target in targets.dropFirst() {
            commonInputFiles.formIntersection(target.inputFiles.map(InputFile.init))
        }

        var errors = [Error]()

        let filesWithSpaceInPath = targets[0].inputFiles.filter { $0.type != .unknown && $0.path.string.firstIndex(of: " ") != nil }
        if !filesWithSpaceInPath.isEmpty {
            errors.append(contentsOf: filesWithSpaceInPath.map(\.path.string).sorted().map(FileWithSpaceInPathError.init))
        }

        for target in targets {
            let inputFiles = Set(target.inputFiles.map(InputFile.init))
            let extraFiles = inputFiles.subtracting(commonInputFiles)

            let expectedExtraFiles = extraInputFiles[target.displayName] ?? []
            let unrelatedFiles = expectedExtraFiles.subtracting(inputFiles)

            if expectedExtraFiles != extraFiles || !unrelatedFiles.isEmpty {
                let error = ExtraFilesInconsistencyError(
                    target: target.displayName,
                    actual: extraFiles,
                    expected: expectedExtraFiles,
                    unrelated: unrelatedFiles
                )
                print(error.localizedDescription)
                errors.append(error)
            }
        }

        try CombinedError(errors: errors).throwIfNonEmpty()
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
