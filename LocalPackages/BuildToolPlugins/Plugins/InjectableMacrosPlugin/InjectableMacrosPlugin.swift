//
//  InjectableMacrosPlugin.swift
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
import PackagePlugin
import XcodeProjectPlugin

enum CustomError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case .message(let text):
            return text
        }
    }
}

struct ListItem: Codable {

    let path: String
    let modified: Date

    init(file: File) throws {
        self.path = file.path.string
        self.modified = try FileManager.default.attributesOfItem(atPath: self.path)[.modificationDate] as? Date ?? .distantPast
    }

}

@main
struct TargetSourcesChecker: BuildToolPlugin, XcodeBuildToolPlugin {

    func createBuildCommands(context: PackagePlugin.PluginContext, target: PackagePlugin.Target) async throws -> [PackagePlugin.Command] {
        return []
    }

    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        let workDir = context.pluginWorkDirectory.appending("gen-\(UUID().uuidString)")

        for file in (try? FileManager.default.contentsOfDirectory(atPath: context.pluginWorkDirectory.string)) ?? [] {
            try? FileManager.default.removeItem(atPath: (context.pluginWorkDirectory.string as NSString).appendingPathComponent(file))
        }
        try FileManager.default.createDirectory(atPath: workDir.string, withIntermediateDirectories: false)

        let files = target.inputFiles.filter { $0.type == .source && $0.path.extension == "swift" }

        let fileListName = "target-source-files.json"
        let fileListPath = context.pluginWorkDirectory.appending(fileListName).string
        try JSONEncoder().encode(files.map(ListItem.init)).write(to: URL(fileURLWithPath: fileListPath))

        // drop /SourcePackages/plugins/DuckDuckGo.output/DuckDuckGo_Privacy_Browser/
//        let workDir = context.pluginWorkDirectory.removingLastComponent().removingLastComponent().removingLastComponent().removingLastComponent().removingLastComponent()
//        let productsDir = workDir.appending(subpath: "Build/Products/Debug")
//        let targetFileListPath = productsDir.appending(fileListName).string

//        let testBuildPath = context.pluginWorkDirectory.appending("test.swift")
//        try """
//        public struct TestDynamicStruct {
//            public init() {}
//            public var hello: String { "hello" }
//        }
//        """.write(toFile: testBuildPath.string, atomically: false, encoding: .utf8)

        let packagePath = context.xcodeProject.directory.appending("LocalPackages/DependencyInjection")
        let home = ProcessInfo().environment["HOME"]!

        return [
            .prebuildCommand(displayName: "Build DependencyInjectionMacros", executable: try context.tool(named: "sh").path, arguments: ["-c", "export HOME=\(home) && source ~/.bashrc && swift build --package-path '\(packagePath)'"], outputFilesDirectory: context.pluginWorkDirectory),
            .prebuildCommand(displayName: "Run DependencyInjectionMacros", executable: try context.tool(named: "sh").path, arguments: ["-c", "cd \(workDir) && find '\(packagePath)/.build' -type f -name DependencyInjectionMacros -exec {} \(fileListPath) \\;"], outputFilesDirectory: workDir)
        ]
    }

}
