//
//  FileSystemDSL.swift
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

enum FileSystemEntity {

    case file(name: String, contents: File.FileContents)
    case directory(name: String, children: [FileSystemEntity])

    var name: String {
        switch self {
        case .file(let name, _): return name
        case .directory(let name, _): return name
        }
    }

}

protocol FileSystemEntityConvertible {

    func asFileSystemEntity() -> FileSystemEntity

}

struct Directory: FileSystemEntityConvertible {

    let name: String
    let children: [FileSystemEntity]

    init(_ name: String, @FileDirectoryStructureBuilder builder: () -> [FileSystemEntity]) {
        self.name = name
        self.children = builder()
    }

    func asFileSystemEntity() -> FileSystemEntity {
        return .directory(name: name, children: children)
    }

}

struct File: FileSystemEntityConvertible {

    enum FileContents {
        case string(String)
        case copy(URL)
    }

    let name: String
    let contents: FileContents

    init(_ name: String, contents: FileContents) {
        self.name = name
        self.contents = contents
    }

    func asFileSystemEntity() -> FileSystemEntity {
        return .file(name: name, contents: contents)
    }

}

@resultBuilder
struct FileDirectoryStructureBuilder {

    static func buildBlock(_ elements: FileSystemEntityConvertible...) -> [FileSystemEntity] {
        return elements.compactMap { $0.asFileSystemEntity() }
    }

}

struct FileSystem {

    var rootDirectoryName: String
    var children: [FileSystemEntity]

    var rootDirectoryURL: URL {
        let temporaryURL = FileManager.default.temporaryDirectory
        return temporaryURL.appendingPathComponent(rootDirectoryName)
    }

    init(rootDirectoryName: String, @FileDirectoryStructureBuilder builder: () -> [FileSystemEntity]) {
        self.rootDirectoryName = rootDirectoryName
        self.children = builder()
    }

    func writeToTemporaryDirectory() throws {
        try FileManager.default.createDirectory(at: rootDirectoryURL, withIntermediateDirectories: false)

        for entity in children {
            try persist(entity: entity, parentDirectoryURL: rootDirectoryURL)
        }
    }

    func removeCreatedFileSystemStructure() throws {
        try FileManager.default.removeItem(at: rootDirectoryURL)
    }

    private func persist(entity: FileSystemEntity, parentDirectoryURL: URL) throws {
        let entityURL = parentDirectoryURL.appendingPathComponent(entity.name)

        switch entity {
        case .file(_, let contents):
            switch contents {
            case .string(let fileContents):
                FileManager.default.createFile(atPath: entityURL.path, contents: fileContents.data(using: .utf8)!)
            case .copy(let fileToCopyURL):
                try FileManager.default.copyItem(at: fileToCopyURL, to: entityURL)
            }
        case .directory(_, let children):
            try FileManager.default.createDirectory(at: entityURL, withIntermediateDirectories: false)

            for directoryChild in children {
                try persist(entity: directoryChild, parentDirectoryURL: entityURL)
            }
        }
    }

}
