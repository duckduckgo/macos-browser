#!/usr/bin/swift

// swiftlint:disable line_length
// swiftlint:disable file_header
// swiftlint:disable function_body_length

import Foundation

let appcastURLString = "https://staticcdn.duckduckgo.com/macos-desktop-browser/appcast2.xml"
let appcastURL = URL(string: appcastURLString)!
let tmpDir = NSString(string: "~/Developer").expandingTildeInPath
let tmpDirURL = URL(fileURLWithPath: tmpDir, isDirectory: true)
let specificDir = tmpDirURL.appendingPathComponent("sparkle-updates")
let appcastFilePath = specificDir.appendingPathComponent("appcast2.xml")
let backupAppcastFilePath = "\(tmpDir)/appcast.xml.backup"
let backupFileURL = URL(fileURLWithPath: backupAppcastFilePath)
let lastCatalinaBuildVersion = "1.55.0"

// MARK: - Arguments

enum Action: String {
    case releaseToInternalChannel = "--release-to-internal-channel"
    case releaseToPublicChannel = "--release-to-public-channel"
    case releaseHotfixToPublicChannel = "--release-hotfix-to-public-channel"
    case help = "--help"
}

struct Arguments {
    let action: Action
    let parameters: [String: String]

    init(args: [String]) throws {
        guard args.count > 1 else {
            throw NSError(domain: "ArgumentsError", code: 1000, userInfo: ["message": "Missing action argument."])
        }
        guard let action = Action(rawValue: args[1]) else {
            throw NSError(domain: "ArgumentsError", code: 1001, userInfo: ["message": "Unknown action."])
        }
        self.action = action

        let remainingArgs = Array(args.dropFirst(2))
        guard remainingArgs.count % 2 == 0 else {
            throw NSError(domain: "ArgumentsError", code: 1002, userInfo: ["message": "Each argument must have a corresponding value."])
        }

        var parameters: [String: String] = [:]
        for index in stride(from: 0, to: remainingArgs.count, by: 2) {
            parameters[remainingArgs[index]] = remainingArgs[index+1]
        }
        self.parameters = parameters
    }
}

// Try to initialize Arguments struct
let arguments: Arguments
do {
    arguments = try Arguments(args: CommandLine.arguments)
} catch {
    if let errorMessage = (error as NSError).userInfo["message"] as? String {
        print(errorMessage)
    }
    exit(1)
}

// Use the arguments
switch arguments.action {

case .help:
    print("""
NAME
    appcastManager – automation of appcast file management

SYNOPSIS
    appcastManager --release-to-internal-channel --dmg <path_to_dmg_file> --release-notes <path_to_release_notes>
    appcastManager --release-to-public-channel --version <version_number> [--release-notes <path_to_release_notes>]
    appcastManager --release-hotfix-to-public-channel --dmg <path_to_dmg_file> --release-notes <path_to_release_notes>
    appcastManager --help

DESCRIPTION
    Automates the process of managing appcast updates, which include releasing app updates to internal or public channels and handling hotfix releases.

    --release-to-internal-channel
        Releases an app update to the internal channel. Requires a path to the DMG file and a path to the release notes.
        Example:
        appcastManager --release-to-internal-channel --dmg /path/to/app.dmg --release-notes /path/to/notes.txt

    --release-to-public-channel
        Releases an app update to the public channel. Requires the version number to be released. Optionally, a path to the release notes can be provided.
        Example:
        appcastManager --release-to-public-channel --version 1.2.3 --release-notes /path/to/notes.txt

    --release-hotfix-to-public-channel
        Releases a hotfix app update to the public channel. Requires a path to the DMG file and a path to the release notes.
        Example:
        appcastManager --release-hotfix-to-public-channel --dmg /path/to/app.dmg --release-notes /path/to/notes.txt

    --help
        Displays this help message.

""")

    exit(0)

case .releaseToInternalChannel, .releaseHotfixToPublicChannel:
    guard let dmgPath = arguments.parameters["--dmg"], let releaseNotesPath = arguments.parameters["--release-notes"] else {
        print("Missing required parameters")
        exit(1)
    }

    print("Action: Add to internal channel")
    print("DMG Path: \(dmgPath)")
    print("Release Notes Path: \(releaseNotesPath)")

    performCommonChecksAndOperations()

    // Handle dmg file
    guard let dmgURL = handleDMGFile(dmgPath: dmgPath, updatesDirectoryURL: specificDir) else {
        exit(1)
    }

    // Handle release notes file
    handleReleaseNotesFile(path: releaseNotesPath, updatesDirectoryURL: specificDir, dmgURL: dmgURL)

    // Extract version number from DMG file name
    let versions = getVersionFromDMGFileName(dmgURL: dmgURL)

    // Differentiate between the two actions
    if arguments.action == .releaseToInternalChannel {
        runGenerateAppcast(withVersions: versions, channel: "internal-channel")
    } else {
        runGenerateAppcast(withVersions: versions)
    }

case .releaseToPublicChannel:
    guard let version = arguments.parameters["--version"] else {
        print("Missing required version parameter for action '--release-to-public-channel'")
        exit(1)
    }

    print("Action: Release to public channel")
    print("Version: \(version)")

    performCommonChecksAndOperations()

    // Verify version
    if !verifyVersion(version: version, atDirectory: specificDir) {
        exit(1)
    }

    // Handle release notes if provided
    if let releaseNotesPath = arguments.parameters["--release-notes"] {
        print("Release Notes Path: \(releaseNotesPath)")
        let dmgURLForPublic = specificDir.appendingPathComponent(getDmgFilename(for: version))
        handleReleaseNotesFile(path: releaseNotesPath, updatesDirectoryURL: specificDir, dmgURL: dmgURLForPublic)
    } else {
        print("No new release notes provided. Keeping existing release notes.")
    }

    // Process appcast content
    if !processAppcastRemovingVersion(version: version, appcastFilePath: appcastFilePath) {
        exit(1)
    }

    runGenerateAppcast(withVersions: version, rolloutInterval: "43200")
}

// MARK: - Common

func performCommonChecksAndOperations() {
    // Check if generate_appcast is recent
    guard checkSparkleToolRecency(toolName: "generate_appcast"),
          checkSparkleToolRecency(toolName: "generate_keys"),
          checkSparkleToolRecency(toolName: "sign_update"),
          checkSparkleToolRecency(toolName: "BinaryDelta") else {
        exit(1)
    }

    // Verify signing keys
    guard verifySigningKeys() else {
        exit(1)
    }

    // Download appcast and update files
    AppcastDownloader().download()
}

func getDmgFilename(for version: String) -> String {
    return "duckduckgo-\(version).dmg"
}

// MARK: - Checking the recency of Sparkle tools

func checkSparkleToolRecency(toolName: String) -> Bool {
    let binaryPath = shell("which", toolName).trimmingCharacters(in: .whitespacesAndNewlines)

    if binaryPath.isEmpty {
        print("Failed to find the path for \(toolName).")
        return false
    }

    guard let binaryAttributes = try? FileManager.default.attributesOfItem(atPath: binaryPath),
          let modificationDate = binaryAttributes[.modificationDate] as? Date else {
        print("Failed to get the modification date for \(toolName).")
        return false
    }

    // Get the current script's path and navigate to the root folder to get the release date file
    let currentScriptPath = URL(fileURLWithPath: #file)
    let rootDirectory = currentScriptPath.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let releaseDateFilePath = rootDirectory.appendingPathComponent(".sparkle_tools_release_date")

    guard let releaseDateString = try? String(contentsOf: releaseDateFilePath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
          let releaseDate = DateFormatter.yyyyMMddUTC.date(from: releaseDateString) else {
        print("Failed to get the release date from .sparkle_tools_release_date.")
        return false
    }

    if modificationDate < releaseDate {
        print("\(toolName) from Sparkle binary utilities is outdated. Please visit https://github.com/sparkle-project/Sparkle/releases and install tools from the latest version.")
        return false
    }

    return true
}

extension DateFormatter {
    static let yyyyMMddUTC: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}

// MARK: - Verification of the signing keys

func verifySigningKeys() -> Bool {
    let publicKeyOutput = shell("generate_keys", "-p").trimmingCharacters(in: .whitespacesAndNewlines)
    let desiredPublicKey = "ZaO/DNMzMPBldh40b5xVrpNBmqRkuGY0BNRCUng2qRo="

    if publicKeyOutput == desiredPublicKey {
        return true
    } else {
        print("Incorrect or missing public signing key. Please ensure you have the correct keys installed.")
        return false
    }
}

// MARK: - Downloading of Appcast and Files

final class AppcastDownloader {

    private let dispatchGroup = DispatchGroup()

    func download() {
        prepareDirectories()
        downloadAppcast()
        dispatchGroup.wait()
        parseAndDownloadFilesFromAppcast()
        dispatchGroup.wait()

        print("All builds downloaded.")
    }

    private func prepareDirectories() {
        // Delete directory if it already exists
        if FileManager.default.fileExists(atPath: specificDir.path) {
            do {
                try FileManager.default.removeItem(at: specificDir)
                print("Old \(specificDir) removed.")
            } catch {
                print("Failed to remove old \(specificDir): \(error).")
                exit(1)
            }
        }

        // Create new directory
        do {
            try FileManager.default.createDirectory(at: specificDir, withIntermediateDirectories: true, attributes: nil)
            print("Directory for new build created.")
        } catch {
            print("Failed to create directory: \(error).")
            exit(1)
        }
    }

    private func downloadFile(_ url: URL, _ destinationURL: URL, completion: @escaping (Error?) -> Void) {
        print("Downloading file from: \(url.absoluteString)")
        let task = URLSession.shared.downloadTask(with: url) { (location, _, error) in
            guard let location = location else {
                completion(error)
                return
            }

            do {
                try FileManager.default.moveItem(at: location, to: destinationURL)
                completion(nil)
            } catch {
                completion(error)
            }
        }
        task.resume()
    }

    private func downloadAppcast() {
        dispatchGroup.enter()
        downloadFile(appcastURL, appcastFilePath) { [self] error in
            if let error = error {
                print("Error downloading appcast: \(error)")
            } else {
                print("Appcast downloaded to: \(appcastFilePath.path)")
            }
            self.dispatchGroup.leave()
        }
    }

    private func parseAndDownloadFilesFromAppcast() {
        let parser = XMLParser(contentsOf: specificDir.appendingPathComponent("appcast2.xml"))
        let delegate = AppcastXMLParserDelegate(downloadFile: downloadFile, dispatchGroup: dispatchGroup)
        parser?.delegate = delegate
        if !(parser?.parse() ?? false) {
            if let error = parser?.parserError {
                print("Error parsing XML: \(error)")
                exit(1)
            }
        }
    }

    final class AppcastXMLParserDelegate: NSObject, XMLParserDelegate {
        var currentElement: String = ""
        var enclosureURL: String = ""
        var releaseNotesHTML: String?
        var currentVersion: String?

        private let downloadFile: (URL, URL, @escaping (Error?) -> Void) -> Void
        private let dispatchGroup: DispatchGroup

        init(downloadFile: @escaping (URL, URL, @escaping (Error?) -> Void) -> Void, dispatchGroup: DispatchGroup) {
            self.downloadFile = downloadFile
            self.dispatchGroup = dispatchGroup
        }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            currentElement = elementName
            if elementName == "enclosure" {
                enclosureURL = attributeDict["url"] ?? ""
                if let url = URL(string: enclosureURL) {
                    let fileName = url.lastPathComponent
                    let destinationURL = specificDir.appendingPathComponent(fileName)
                    self.dispatchGroup.enter()
                    self.downloadFile(url, destinationURL) { error in
                        if let error = error {
                            print("Error downloading file: \(error)")
                        } else {
                            print("File downloaded to: \(destinationURL.path)")
                        }
                        self.dispatchGroup.leave()
                    }
                }
            } else if elementName == "item" {
                currentVersion = nil
                releaseNotesHTML = nil
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if currentElement == "description" {
                releaseNotesHTML = (releaseNotesHTML ?? "") + string.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if currentElement == "sparkle:version" {
                currentVersion = ((currentVersion ?? "") + string.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            if elementName == "item" {
                if let releaseNotesHTML = releaseNotesHTML, let version = currentVersion {
                    let releaseNotesPath = specificDir.appendingPathComponent("duckduckgo-\(version).html").path
                    do {
                        try releaseNotesHTML.write(toFile: releaseNotesPath, atomically: true, encoding: .utf8)
                    } catch {
                        print("Failed to write release notes: \(error)")
                        exit(1)
                    }
                    print("Release notes for \(version) saved into \(releaseNotesPath)")
                }
            }
        }

        func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
            print("XML Parse Error: \(parseError)")
            exit(1)
        }
    }
}

// MARK: - Handling of Release Notes

func handleReleaseNotesFile(path: String, updatesDirectoryURL: URL, dmgURL: URL) {
    // Copy release notes file and rename it to match the dmg filename
    let releaseNotesURL = URL(fileURLWithPath: path)
    let destinationReleaseNotesURL = updatesDirectoryURL.appendingPathComponent(dmgURL.deletingPathExtension().lastPathComponent + ".html")

    do {
        if FileManager.default.fileExists(atPath: destinationReleaseNotesURL.path) {
            try FileManager.default.removeItem(at: destinationReleaseNotesURL)
            print("Old release notes file removed.")
        }

        // Load the release notes from the txt file
        let releaseNotes = try String(contentsOf: releaseNotesURL, encoding: .utf8)

        // Convert the release notes to HTML
        let releaseNotesLines = releaseNotes.split(separator: "\n")
        let releaseNotesListItems = releaseNotesLines.map { "<li>\($0)</li>" }.joined(separator: "\n")
        let releaseNotesHTML = """
        <h3 style="font-size:14px">What's new</h3>
        <ul style="font-size:12px">
        \(releaseNotesListItems)
        </ul>
        """

        // Save the converted release notes to the destination file
        try releaseNotesHTML.write(to: destinationReleaseNotesURL, atomically: true, encoding: .utf8)
        print("New release notes file copied to the updates directory and converted to HTML.")

    } catch {
        print("Failed to copy and convert release notes file: \(error).")
        exit(1)
    }
}

func getVersionFromDMGFileName(dmgURL: URL) -> String {
    // Extract version number from DMG file name
    let filename = dmgURL.lastPathComponent
    let components = filename.components(separatedBy: "-")
    guard components.count >= 2 else {
        print("Invalid DMG file name format. Expected 'duckduckgo-X.Y.Z.dmg'")
        exit(1)
    }
    let versionWithExtension = components[1]
    let versionComponents = versionWithExtension.components(separatedBy: ".dmg")
    let versions = versionComponents[0]
    return versions
}

// MARK: - Handling of DMG Files

func handleDMGFile(dmgPath: String, updatesDirectoryURL: URL) -> URL? {
    let dmgURL = URL(fileURLWithPath: dmgPath)
    let destinationDMGURL = updatesDirectoryURL.appendingPathComponent(dmgURL.lastPathComponent)
    do {
        if FileManager.default.fileExists(atPath: destinationDMGURL.path) {
            try FileManager.default.removeItem(at: destinationDMGURL)
            print("Old dmg file removed.")
        }
        try FileManager.default.copyItem(at: dmgURL, to: destinationDMGURL)
        print("New dmg file copied to the updates directory.")
        return destinationDMGURL
    } catch {
        print("Failed to copy dmg file: \(error).")
        return nil
    }
}

func verifyVersion(version: String, atDirectory dir: URL) -> Bool {
    let expectedDMGFileName = getDmgFilename(for: version)
    let expectedDMGFilePath = dir.appendingPathComponent(expectedDMGFileName).path
    if FileManager.default.fileExists(atPath: expectedDMGFilePath) {
        print("Verified: Version \(version) exists in the downloaded appcast items.")
        return true
    } else {
        print("Version \(version) does not exist in the downloaded appcast items.")
        return false
    }
}

// MARK: - Processing of Appcast

func processAppcastRemovingVersion(version: String, appcastFilePath: URL) -> Bool {
    guard let appcastContent = readAppcastContent(from: appcastFilePath) else {
        print("Failed to read the appcast file.")
        return false
    }
    guard let modifiedAppcastContent = removeVersionFromAppcast(version, appcastContent: appcastContent) else {
        print("Failed to remove version \(version) from the appcast.")
        return false
    }
    writeAppcastContent(modifiedAppcastContent, to: appcastFilePath)
    print("Version \(version) removed from the appcast.")
    return true
}

func readAppcastContent(from filePath: URL) -> String? {
    try? String(contentsOf: filePath, encoding: .utf8)
}

func removeVersionFromAppcast(_ version: String, appcastContent: String) -> String? {
    let pattern = "(<item>\\s*<title>\\s*\(version)\\s*</title>.*?</item>)"

    guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators),
          let startMatch = regex.firstMatch(in: appcastContent, range: NSRange(appcastContent.startIndex..., in: appcastContent)),
          let endRange = appcastContent.range(of: "</item>", options: [], range: Range(startMatch.range, in: appcastContent)!)
    else {
        print("Failed to match version \(version) in the appcast content.")
        return nil
    }

    var modifiedAppcastContent = appcastContent
    modifiedAppcastContent.removeSubrange(Range(startMatch.range, in: appcastContent)!.lowerBound..<endRange.upperBound)
    return modifiedAppcastContent
}

func writeAppcastContent(_ content: String, to filePath: URL) {
    do {
        try content.write(to: filePath, atomically: true, encoding: .utf8)
    } catch {
        print("Failed to write the modified appcast file: \(error).")
        exit(1)
    }
}

// MARK: - Generating of New Appcast

func runGenerateAppcast(withVersions versions: String, channel: String? = nil, rolloutInterval: String? = nil) {
    // Check if backup file already exists and remove it
    if FileManager.default.fileExists(atPath: backupFileURL.path) {
        do {
            try FileManager.default.removeItem(at: backupFileURL)
        } catch {
            print("Error removing existing backup file: \(error)")
            exit(1)
        }
    }

    // Create a new backup of the appcast file
    do {
        try FileManager.default.copyItem(at: appcastFilePath, to: backupFileURL)
    } catch {
        print("Error backing up appcast2.xml: \(error)")
        exit(1)
    }

    let maximumVersions = "2"
    let maximumDeltas = "2"

    var commandComponents: [String] = []
    commandComponents.append("generate_appcast")
    commandComponents.append("--versions \(versions)")
    commandComponents.append("--maximum-versions \(maximumVersions)")
    commandComponents.append("--maximum-deltas \(maximumDeltas)")

    if let channel = channel {
        commandComponents.append("--channel \(channel)")
    }

    if let rolloutInterval = rolloutInterval {
        commandComponents.append("--phased-rollout-interval \(rolloutInterval)")
    }

    commandComponents.append("--embed-release-notes ")
    commandComponents.append("\(specificDir.path)")

    let command = commandComponents.joined(separator: " ")

    // Execute the command
    let task = Process()
    task.launchPath = "/usr/bin/env"
    task.arguments = ["bash", "-c", command]

    task.launch()
    task.waitUntilExit()

    if task.terminationStatus != 0 {
        print("generate_appcast command failed with exit code \(task.terminationStatus).")
        exit(1)
    }

    print("generate_appcast command executed successfully.")

    // Verify presense of old builds
    if !verifyAppcastContainsBuild(lastCatalinaBuildVersion, in: appcastFilePath) {
        print("Error: Appcast does not contain the build (\(lastCatalinaBuildVersion)).")
        exit(1)
    }

    // Get and save the diff
    let diffResult = shell("diff", backupAppcastFilePath, appcastFilePath.path)
    let diffFilePath = specificDir.appendingPathComponent("appcast_diff.txt").path
    do {
        try diffResult.write(toFile: diffFilePath, atomically: true, encoding: .utf8)
        print("Differences in appcast file saved to: \(diffFilePath)")
    } catch {
        print("Error writing diff to file: \(error)")
    }

    // Move files back to the original location
    moveFiles(from: specificDir.appendingPathComponent("old_updates"), to: specificDir)
    print("Old update files moved back to \(specificDir.path)")

    // Open specific directory in Finder
    shell("open", specificDir.path)
}

func moveFiles(from sourceDir: URL, to destinationDir: URL) {
    let fileManager = FileManager.default
    do {
        let fileURLs = try fileManager.contentsOfDirectory(at: sourceDir, includingPropertiesForKeys: nil)
        for fileURL in fileURLs {
            let destinationURL = destinationDir.appendingPathComponent(fileURL.lastPathComponent)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: fileURL, to: destinationURL)
        }
    } catch {
        print("Failed to move files from \(sourceDir.path) to \(destinationDir.path): \(error).")
        exit(1)
    }
}

@discardableResult func shell(_ command: String, _ arguments: String...) -> String {
    let task = Process()
    task.launchPath = "/usr/bin/env"
    task.arguments = [command] + arguments

    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()
    task.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}

// - MARK: - Ensuring old builds remain in the appcast

func verifyAppcastContainsBuild(_ buildVersion: String, in filePath: URL) -> Bool {
    guard let appcastContent = try? String(contentsOf: filePath, encoding: .utf8) else {
        print("Failed to read the appcast file.")
        return false
    }

    let buildString = "<sparkle:version>\(buildVersion)</sparkle:version>"
    return appcastContent.contains(buildString)
}

// swiftlint:enable line_length
// swiftlint:enable function_body_length
