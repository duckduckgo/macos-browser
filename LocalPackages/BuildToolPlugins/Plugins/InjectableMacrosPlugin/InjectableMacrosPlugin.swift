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

extension String {
    static let generated = "generated"
    static let swift = "swift"
    static let generatedSwift = String.generated + "." + .swift
    static let Injectable = "Injectable"

    func appendingPathExtension(_ ext: String) -> String {
        (self as NSString).appendingPathExtension(ext) ?? self
    }

}

extension PackagePlugin.Path {

    var modified: Date {
        get throws {
            try FileManager.default.attributesOfItem(atPath: self.string)[.modificationDate] as? Date ?? { throw CocoaError(.fileReadUnknown) }()
        }
    }

}

struct InputListItem: Codable {

    let modified: Date
    let hasInjectable: Bool

    init(modified: Date, hasInjectable: Bool) {
        self.modified = modified
        self.hasInjectable = hasInjectable
    }

}

@main
struct TargetSourcesChecker: BuildToolPlugin, XcodeBuildToolPlugin {

    func createBuildCommands(context: PackagePlugin.PluginContext, target: PackagePlugin.Target) async throws -> [PackagePlugin.Command] {
        return []
    }

#if swift(>=5.9)

    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        return []
    }

#else

    // swiftlint:disable cyclomatic_complexity
    // swiftlint:disable function_body_length
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        let fm = FileManager.default
        let formatter = ISO8601DateFormatter()

        let buildProductsDir = context.pluginWorkDirectory.removingLastComponent().removingLastComponent().removingLastComponent().removingLastComponent().removingLastComponent()
            .appending("Build", "Products")
        if !fm.fileExists(atPath: buildProductsDir.string) {
            // performing clean build
            for file in (try? fm.contentsOfDirectory(atPath: context.pluginWorkDirectory.string)) ?? [] {
                try? fm.removeItem(atPath: context.pluginWorkDirectory.appending(file).string)
            }
        }

        // directory where generated content will go
        let workDir = context.pluginWorkDirectory.appending(.generated)
        try? fm.createDirectory(atPath: workDir.string, withIntermediateDirectories: false)

        // empty directory as an “output directory” for the Build DependencyInjectionMacros step
        let emptyDir = context.pluginWorkDirectory.appending("empty-output-dummy")
        try? fm.createDirectory(atPath: workDir.string, withIntermediateDirectories: false)

        // map input file paths to according .generated.swift filename
        let files: [PackagePlugin.Path: String] = target.inputFiles.reduce(into: [:]) { result, file in
            guard file.type == .source && file.path.extension == .swift else { return }

            let generatedFileName = file.path.stem.appendingPathExtension(.generatedSwift)

            result[file.path] = generatedFileName
        }

        // already generated files
        let generatedFileNames = Set(try fm.contentsOfDirectory(atPath: workDir.string))

        // delete orphaned files
        let orphanedFiles = generatedFileNames.subtracting(files.values)
        for file in orphanedFiles {
            try fm.removeItem(atPath: workDir.appending(file).string)
        }

        // load input files cache from last pass
        let cacheURL = URL(fileURLWithPath: context.pluginWorkDirectory.appending("cache.json").string)
        var cache = (try? JSONDecoder().decode([String: InputListItem].self, from: Data(contentsOf: cacheURL))) ?? [:]

        // find modified source files
        let filesToProcess = try files.compactMap { (inputPath, generatedFileName) -> String? in
            return try autoreleasepool {
                let generatedPath = workDir.appending(generatedFileName)
                var _modified: Date? // swiftlint:disable:this identifier_name
                var modified: Date {
                    get throws {
                        if _modified == nil {
                            _modified = try inputPath.modified
                        }
                        return _modified!
                    }
                }

                // if there‘s already generated file for the input
                if fm.fileExists(atPath: generatedPath.string) {
                    // compare input modification date to the generated file header
                    let expectedHeader = ("// " + formatter.string(from: try modified)).data(using: .utf8)!
                    let handle = try FileHandle(forReadingAtPath: generatedPath.string) ?? { throw CocoaError(.fileReadUnknown) }()
                    let header = handle.readData(ofLength: expectedHeader.count)
                    handle.closeFile()

                    if header == expectedHeader {
                        // source file not modified since last generation
                        return nil
                    }
                }
                let hasInjectable: Bool
                if let inputItem = cache[inputPath.string], try modified == inputItem.modified {
                    // the input file was already scanned in last pass, load `hasInjectable` from cache
                    hasInjectable = inputItem.hasInjectable
                } else {
                    // input file should have "Injectable" present in content
                    let contents = try NSString(contentsOfFile: inputPath.string, encoding: NSUTF8StringEncoding)
                    hasInjectable = contents.range(of: .Injectable).location != NSNotFound
                    cache[inputPath.string] = InputListItem(modified: try modified, hasInjectable: hasInjectable)
                }

                // if Injectable implementation removed from the source file: remove generated file
                guard hasInjectable else {
                    if fm.fileExists(atPath: generatedPath.string) {
                        try fm.removeItem(atPath: generatedPath.string)
                    }
                    return nil
                }

                return "'\(inputPath.string)'"
            }
        }
        try JSONEncoder().encode(cache).write(to: cacheURL)

        guard !filesToProcess.isEmpty else {
            return [
                .prebuildCommand(displayName: "DependencyInjectionMacros", executable: try context.tool(named: "echo").path, arguments: ["rebuild not needed"], outputFilesDirectory: workDir)
            ]
        }

        let packagePath = context.xcodeProject.directory.appending("LocalPackages", "DependencyInjection")
#if arch(x86_64)
        let arch = "x86_64-apple-macosx"
#elseif arch(arm64)
        let arch = "arm64-apple-macosx"
#endif
        let macroToolPath = packagePath.appending(".build", arch, "*", "DependencyInjectionMacros")
            .string.replacingOccurrences(of: " ", with: "\\ ")
        let home = ProcessInfo().environment["HOME"]!

        return [
            .prebuildCommand(displayName: "Build DependencyInjectionMacros", executable: try context.tool(named: "sh").path, arguments: ["-c", "export HOME=\(home) && source ~/.bashrc && swift build --package-path '\(packagePath)'"], outputFilesDirectory: emptyDir),
            .prebuildCommand(displayName: "DependencyInjectionMacros", executable: try context.tool(named: "sh").path, arguments: ["-c", "cd \(workDir); \(macroToolPath) \(filesToProcess.joined(separator: " "))"], outputFilesDirectory: workDir)
        ]
    }
    // swiftlint:enable cyclomatic_complexity
    // swiftlint:enable function_body_length

#endif

}
