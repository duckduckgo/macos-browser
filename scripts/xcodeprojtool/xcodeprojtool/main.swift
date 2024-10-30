//
//  main.swift
//  xcodeprojtool
//
//  Created by Dominik Kapusta on 30/10/2024.
//

import Foundation
import RegexBuilder

extension FileHandle {
    func readLine() -> String? {
        let newlineChar = "\n".data(using: .utf8)!
        var line = Data()

        while let byte = self.readData(ofLength: 1).first {
            if byte == newlineChar.first {
                return String(data: line, encoding: .utf8)
            }
            line.append(byte)
        }

        return line.isEmpty ? nil : String(data: line, encoding: .utf8)
    }
}

let path = "/Users/ayoy/code/macos-browser/DuckDuckGo.xcodeproj/project.pbxproj"

func readXcodeProject(at path: String) throws -> [String: Any]? {

    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)

        return plist as? [String: Any]
    } catch {
        print("Error: \(error)")
        return nil
    }
}

func findObjectsToDelete(in xcodeProject: [String: Any]) -> Set<String> {
    let objects = xcodeProject["objects"] as! [String: Any]
    let objectsToDelete = objects.compactMap { key, value -> String? in
        guard let valueDict = value as? [String: Any],
              let isa = valueDict["isa"] as? String,
              let productName = valueDict["productName"] as? String,
              isa == "XCSwiftPackageProductDependency",
              productName != "Swifter"
        else {
            return nil
        }
        return key
    }
    return Set(objectsToDelete)
}

func remove(_ objects: Set<String>, fromXcodeProjectFileAt path: String) throws {
    guard let fileHandle = FileHandle(forReadingAtPath: path) else {
        print("Failed to open file")
        return
    }

    var output = String()

    let objectStartRegex = Regex {
        Anchor.startOfLine
        "\t\t"
        Capture {
            OneOrMore(.hexDigit)
        }
    }

    let objectEndRegex = try Regex("^\t\t};")

    var isInObject: Bool = false

    while let line = fileHandle.readLine() {
        if isInObject {
            if line.starts(with: objectEndRegex) {
                isInObject = false
            }
            continue
        } else {
            if let objectIDMatch = try objectStartRegex.firstMatch(in: line), objects.contains(String(objectIDMatch.1)) {
                isInObject = true
            } else {
                output.append(line + "\n")
            }
        }
    }

    fileHandle.closeFile()
    try output.data(using: .utf8)?.write(to: URL(fileURLWithPath: path).appendingPathExtension("new"))
}

// MARK: -

guard let xcodeProject = try readXcodeProject(at: path) else {
    exit(1)
}

let objectsToDelete = findObjectsToDelete(in: xcodeProject)

try remove(objectsToDelete, fromXcodeProjectFileAt: path)
