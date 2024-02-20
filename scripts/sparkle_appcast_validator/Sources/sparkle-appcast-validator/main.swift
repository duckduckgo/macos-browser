// The Swift Programming Language
// https://docs.swift.org/swift-book

import Sparkle
import SparklePrivateHeaders

// 1. Get Appcast file path:

let arguments = ProcessInfo.processInfo.arguments

if arguments.count != 2 {
    print("❌ ERROR: Missing appcast file reference")
    exit(EXIT_FAILURE)
}

let filePathArgument = arguments[1]
let filePath = URL(fileURLWithPath: filePathArgument)

if !FileManager.default.fileExists(atPath: filePathArgument) {
    print("❌ ERROR: Could not find file at \(filePath)")
    exit(EXIT_FAILURE)
}

// 2: Read contents of Appcast:

guard let appcastData = try? Data(contentsOf: filePath) else {
    print("❌ ERROR: Failed to read file at \(filePath)")
    exit(EXIT_FAILURE)
}

// 3: Parse Appcast file data as SUAppcast:

let hostVersion = "1.0"
let versionComparator = SUStandardVersionComparator.default
let stateResolver = SPUAppcastItemStateResolver(
    hostVersion: hostVersion,
    applicationVersionComparator: versionComparator,
    standardVersionComparator: versionComparator
)

do {
    let appcast = try SUAppcast(xmlData: appcastData, relativeTo: nil, stateResolver: stateResolver)

    print("Appcast entries:")

    for appcastItem in appcast.items {
        guard let appcastItemTitle = appcastItem.title else {
            print("❌ ERROR: Failed to get title for Appcast item with version \(appcastItem.versionString)")
            exit(EXIT_FAILURE)
        }

        print("  • \(appcastItemTitle), version \(appcastItem.versionString)")
    }

    print("✅ SUCCESS: All Appcast items validated")
    exit(EXIT_SUCCESS)
} catch {
    print("❌ ERROR: Failed to parse Appcast, with error: \(error.localizedDescription)")
}
