#!/usr/bin/swift

// swiftlint:disable line_length
// swiftlint:disable file_header
// swiftlint:disable function_body_length

import Foundation

signal(SIGINT) { _ in
    print("Received Ctrl+C. Terminating...")
    exit(1)
}

let isCI = ProcessInfo.processInfo.environment["CI"] != nil
let appcastURLString = "https://staticcdn.duckduckgo.com/macos-desktop-browser/appcast2.xml"
let appcastURL = URL(string: appcastURLString)!
let tmpDir = isCI ? "." : NSString(string: "~/Developer").expandingTildeInPath
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
    appcastManager --release-to-internal-channel --dmg <path_to_dmg_file> --release-notes <path_to_release_notes> [--key <path_to_private_key>]
    appcastManager --release-to-public-channel --version <version_identifier> [--release-notes <path_to_release_notes>] [--key <path_to_private_key>]
    appcastManager --release-hotfix-to-public-channel --dmg <path_to_dmg_file> --release-notes <path_to_release_notes> [--key <path_to_private_key>]
    appcastManager --release-to-internal-channel --dmg <path_to_dmg_file> --release-notes-html <path_to_release_notes_html> [--key <path_to_private_key>]
    appcastManager --release-to-public-channel --version <version_identifier> [--release-notes-html <path_to_release_notes_html>] [--key <path_to_private_key>]
    appcastManager --release-hotfix-to-public-channel --dmg <path_to_dmg_file> --release-notes-html <path_to_release_notes_html> [--key <path_to_private_key>]
    appcastManager --help

DESCRIPTION
    Automates the process of managing appcast updates, which include releasing app updates to internal or public channels and handling hotfix releases.

    --release-to-internal-channel
        Releases an app update to the internal channel. Requires a path to the DMG file and a path to the release notes.
        Example:
        appcastManager --release-to-internal-channel --dmg /path/to/app.dmg --release-notes /path/to/notes.txt

    --release-to-public-channel
        Releases an app update to the public channel. Requires the identifier of the version to be released
        (marketing version + build number, dot-separated). Optionally, a path to the release notes can be provided.
        Example:
        appcastManager --release-to-public-channel --version 1.2.3.45 --release-notes /path/to/notes.txt

    --release-hotfix-to-public-channel
        Releases a hotfix app update to the public channel. Requires a path to the DMG file and a path to the release notes.
        Example:
        appcastManager --release-hotfix-to-public-channel --dmg /path/to/app.dmg --release-notes /path/to/notes.txt

    --help
        Displays this help message.

""")

    exit(0)

case .releaseToInternalChannel, .releaseHotfixToPublicChannel:
    guard let dmgPath = arguments.parameters["--dmg"] else {
        print("Missing required parameters")
        exit(1)
    }
    let releaseNotesPath = arguments.parameters["--release-notes"]
    let releaseNotesHTMLPath = arguments.parameters["--release-notes-html"]
    guard releaseNotesPath != nil || releaseNotesHTMLPath != nil else {
        print("Missing required parameters")
        exit(1)
    }
    let keyFile = readKeyFileArgument()

    print("➡️  Action: Add to internal channel")
    print("➡️  DMG Path: \(dmgPath)")
    if let releaseNotesPath {
        print("➡️  Release Notes Path: \(releaseNotesPath)")
    } else if let releaseNotesHTMLPath {
        print("➡️  Release Notes HTML Path: \(releaseNotesHTMLPath)")
    }
    if isCI, let keyFile {
        print("➡️  Key file: \(keyFile)")
    }

    performCommonChecksAndOperations()

    // Handle dmg file
    guard let dmgURL = handleDMGFile(dmgPath: dmgPath, updatesDirectoryURL: specificDir) else {
        exit(1)
    }

    // Handle release notes file
    if let releaseNotesPath {
        handleReleaseNotesFile(path: releaseNotesPath, updatesDirectoryURL: specificDir, dmgURL: dmgURL)
    } else if let releaseNotesHTMLPath {
        handleReleaseNotesHTML(path: releaseNotesHTMLPath, updatesDirectoryURL: specificDir, dmgURL: dmgURL)
    }

    // Extract version number from DMG file name
    let versionNumber = getVersionNumberFromDMGFileName(dmgURL: dmgURL)

    // Differentiate between the two actions
    if arguments.action == .releaseToInternalChannel {
        runGenerateAppcast(with: versionNumber, channel: "internal-channel", keyFile: keyFile)
    } else {
        runGenerateAppcast(with: versionNumber, keyFile: keyFile)
    }

case .releaseToPublicChannel:
    guard let versionIdentifier = arguments.parameters["--version"] else {
        print("Missing required version parameter for action '--release-to-public-channel'")
        exit(1)
    }
    let keyFile = readKeyFileArgument()

    let versionNumber = extractVersionNumber(from: versionIdentifier)

    print("➡️  Action: Release to public channel")
    print("➡️  Version: \(versionIdentifier)")
    if isCI, let keyFile {
        print("➡️  Key file: \(keyFile)")
    }

    performCommonChecksAndOperations()

    guard let dmgFileName = findDMG(for: versionIdentifier, in: specificDir) else {
        print("❌ Version \(versionIdentifier) does not exist in the downloaded appcast items.")
        exit(1)
    }
    print("Verified: Version \(versionIdentifier) exists in the downloaded appcast items: \(dmgFileName)")

    // Handle release notes if provided
    if let releaseNotesPath = arguments.parameters["--release-notes"] {
        print("Release Notes Path: \(releaseNotesPath)")
        let dmgURLForPublic = specificDir.appendingPathComponent(dmgFileName)
        handleReleaseNotesFile(path: releaseNotesPath, updatesDirectoryURL: specificDir, dmgURL: dmgURLForPublic)
    } else if let releaseNotesHTMLPath = arguments.parameters["--release-notes-html"] {
        print("Release Notes Path: \(releaseNotesHTMLPath)")
        let dmgURLForPublic = specificDir.appendingPathComponent(dmgFileName)
        handleReleaseNotesHTML(path: releaseNotesHTMLPath, updatesDirectoryURL: specificDir, dmgURL: dmgURLForPublic)
    } else {
        print("👀 No new release notes provided. Keeping existing release notes.")
    }

    // Process appcast content
    guard processAppcast(removing: versionNumber, appcastFilePath: appcastFilePath) else {
        exit(1)
    }
    print("⚠️  Version \(versionIdentifier) removed from the appcast.")

    runGenerateAppcast(with: versionNumber, rolloutInterval: "43200", keyFile: keyFile)
}

// MARK: - Common

func readKeyFileArgument() -> String? {
    let keyFile: String? = arguments.parameters["--key"]

    if isCI {
        print("Running in CI mode")
        guard keyFile != nil else {
            print("Missing required key parameter for CI")
            exit(1)
        }
    }

    return keyFile
}

func extractVersionNumber(from versionIdentifier: String) -> String {
    let components = versionIdentifier.components(separatedBy: ".")
    guard components.count == 4 else {
        print("❌ Invalid version identifier format. Expected 'X.Y.Z.B'")
        exit(1)
    }
    let versionNumber = components[3]
    return versionNumber
}

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

// MARK: - Checking the recency of Sparkle tools

func checkSparkleToolRecency(toolName: String) -> Bool {
    let binaryPath = shell("which", toolName).trimmingCharacters(in: .whitespacesAndNewlines)

    if binaryPath.isEmpty {
        print("❌ Failed to find the path for \(toolName).")
        return false
    }

    guard let binaryAttributes = try? FileManager.default.attributesOfItem(atPath: binaryPath),
          let modificationDate = binaryAttributes[.modificationDate] as? Date else {
        print("❌ Failed to get the modification date for \(toolName).")
        return false
    }

    // Get the current script's path and navigate to the root folder to get the release date file
    let currentScriptPath = URL(fileURLWithPath: #file)
    let rootDirectory = currentScriptPath.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let releaseDateFilePath = rootDirectory.appendingPathComponent(".sparkle_tools_release_date")

    guard let releaseDateString = try? String(contentsOf: releaseDateFilePath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
          let releaseDate = DateFormatter.yyyyMMddUTC.date(from: releaseDateString) else {
        print("❌ Failed to get the release date from .sparkle_tools_release_date.")
        return false
    }

    if modificationDate < releaseDate {
        print("❌ \(toolName) from Sparkle binary utilities is outdated. Please visit https://github.com/sparkle-project/Sparkle/releases and install tools from the latest version.")
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
    if isCI {
        print("Running in CI mode. Skipping verification of signing keys.")
        return true
    }
    let publicKeyOutput = shell("generate_keys", "-p").trimmingCharacters(in: .whitespacesAndNewlines)
    let desiredPublicKey = "ZaO/DNMzMPBldh40b5xVrpNBmqRkuGY0BNRCUng2qRo="

    if publicKeyOutput == desiredPublicKey {
        return true
    } else {
        print("❌ Incorrect or missing public signing key. Please ensure you have the correct keys installed.")
        return false
    }
}

// MARK: - Downloading of Appcast and Files

final class AppcastDownloader {

    private let dispatchGroup = DispatchGroup()
    private let cacheDir = specificDir.appendingPathComponent("cache")
    private var downloadTasks = [String: URLSessionDownloadTask]() {
        didSet {
            guard oldValue.isEmpty && downloadTasks.count == 1 else { return }

            // Report download progress
            timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now(), repeating: 0.5)
            timer.setEventHandler {
                guard !self.downloadTasks.isEmpty else {
                    self.timer.cancel()
                    self.timer = nil
                    return
                }
                let progress = self.downloadTasks.values.reduce((total: Int64(0), received: Int64(0))) { result, task in
                    guard task.countOfBytesExpectedToReceive > 0 else { return result }
                    return (total: result.total + task.countOfBytesExpectedToReceive, received: result.received + task.countOfBytesReceived)
                }

                updateProgress(progress.total, received: progress.received)
            }
            timer.resume()
        }
    }
    private let queue = DispatchQueue(label: "AppcastDownloader.queue")
    private var timer: DispatchSourceTimer!

    func download() {
        prepareDirectories()
        downloadAppcast()
        dispatchGroup.wait()
        backupAppcast()
        parseAndDownloadFilesFromAppcast()
        dispatchGroup.wait()

        print("🥬 All builds downloaded.",
              "                                              ") // overwrite progress bar
        cleanup()
    }

    private func prepareDirectories() {
        let fm = FileManager.default

        guard !fm.fileExists(atPath: specificDir.path) || specificDir.isDirectory else {
            print("❌ There‘s an existing file at \(specificDir.path)")
            exit(1)
        }

        do {
            if !cacheDir.isDirectory {
                print("Creating ", cacheDir.path)
                try? fm.removeItem(at: cacheDir)
                try fm.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
            }
        } catch {
            print("❌ Failed to create directory \(cacheDir.path): \(error).")
            exit(1)
        }

        // Clean-up sparkle-updates directory
        for file in (try? fm.contentsOfDirectory(atPath: specificDir.path)) ?? [] {
            let url = specificDir.appendingPathComponent(file)
            guard url.path != cacheDir.path else { continue }

            do {
                // cache old .dmg and .delta files
                if ["dmg", "delta"].contains(url.pathExtension) {
                    do {
                        let cachedUrl = cacheDir.appendingPathComponent(file)
                        if fm.fileExists(atPath: cachedUrl.path) {
                            print("Removing \(cachedUrl.path)")
                            try fm.removeItem(at: cachedUrl)
                        }
                        print("Caching \(url.path)")
                        try fm.moveItem(at: url, to: cachedUrl)
                    } catch {
                        print("❗️ Failed to move file \(url.path) to cache, removing: \(error)")
                        try fm.removeItem(at: url)
                    }
                } else {
                    print("Removing \(url.path)")
                    try fm.removeItem(at: url)
                }

            } catch {
                print("❌ Failed to remove \(url.path): \(error).")
                exit(1)
            }
        }
    }

    private func downloadFile(_ url: URL, _ destinationURL: URL, cachePolicy: URLRequest.CachePolicy, completion: @escaping (Error?) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        if cachePolicy != .returnCacheDataElseLoad {
            reallyDownloadFile(url, destinationURL, cachePolicy: cachePolicy, completion: completion)
            return
        }

        // Create a data task with the HEAD request to receive a remote file length
        let task = URLSession.shared.dataTask(with: request) { (_, response, error) in
            if let error = error {
                completion(error)

            } else if let response = response as? HTTPURLResponse {
                if response.statusCode == 200 {
                    // do we already have a cached file of the same size?
                    if self.useCachedFileIfValid(for: destinationURL, response: response) {
                        print("💾 Using cached file for \(destinationURL.path)")
                        completion(nil)
                        return
                    }

                    // file not cached, download
                    self.reallyDownloadFile(url, destinationURL, cachePolicy: cachePolicy, completion: completion)

                } else {
                    print("❌ Server did status code \(response.statusCode) for \(destinationURL.lastPathComponent). Aborting download.")
                    completion(NSError(domain: "HTTPURLResponseCode", code: response.statusCode, userInfo: nil))
                }

            } else {
                completion(NSError(domain: "NotHTTPURLResponse", code: 0, userInfo: nil))
            }
        }

        task.resume()
    }

    /// compare HTTP Response expected content length with a cached file size
    /// move it to the destinationURL if matches
    ///
    /// returns: `true` if cached file found and moved to the destinationURL, `false` - otherwise
    private func useCachedFileIfValid(for destinationURL: URL, response: HTTPURLResponse) -> Bool {
        let cachedFileUrl = cacheDir.appendingPathComponent(destinationURL.lastPathComponent)
        let fm = FileManager.default

        guard fm.fileExists(atPath: cachedFileUrl.path) else { return false }

        guard let attributes = try? fm.attributesOfItem(atPath: cachedFileUrl.path),
              let fileSize = attributes[.size] as? Int,
              fileSize == response.expectedContentLength else {
            print("❗️ Invalidating cached file: \(destinationURL.path)")
            try? fm.removeItem(at: destinationURL)
            return false
        }

        do {
            try fm.moveItem(at: cachedFileUrl, to: destinationURL)
            return true

        } catch {
            print("❗️ Could not move cached file \(cachedFileUrl.path) to \(destinationURL.path): \(error)")
            return false
        }
    }

    private func reallyDownloadFile(_ url: URL, _ destinationURL: URL, cachePolicy: URLRequest.CachePolicy, completion: @escaping (Error?) -> Void) {
        print("⬇️  Downloading file from: \(url.absoluteString)")
        let request = URLRequest(url: url, cachePolicy: cachePolicy)
        let task = URLSession.shared.downloadTask(with: request) { (location, _, error) in
            self.queue.async {
                self.downloadTasks[destinationURL.lastPathComponent] = nil
            }

            guard let location = location else {
                completion(error)
                return
            }

            do {
                try FileManager.default.moveItem(at: location, to: destinationURL)
                print("✅ File downloaded to: \(destinationURL.path)")
                completion(nil)
            } catch {
                completion(error)
            }
        }

        queue.async {
            self.downloadTasks[destinationURL.lastPathComponent] = task
        }

        task.resume()
    }

    private func downloadAppcast() {
        dispatchGroup.enter()
        downloadFile(appcastURL, appcastFilePath, cachePolicy: .useProtocolCachePolicy) { [self] error in
            if let error = error {
                print("❌ Error downloading appcast: \(error)")
                exit(1)
            } else {
                print("✅ Appcast downloaded to: \(appcastFilePath.path)")
                self.dispatchGroup.leave()
            }
        }
    }

    private func backupAppcast() {
        // Check if backup file already exists and remove it
        if FileManager.default.fileExists(atPath: backupFileURL.path) {
            do {
                try FileManager.default.removeItem(at: backupFileURL)
            } catch {
                print("❌ Error removing existing backup file: \(error)")
                exit(1)
            }
        }

        // Create a new backup of the appcast file
        do {
            try FileManager.default.copyItem(at: appcastFilePath, to: backupFileURL)
        } catch {
            print("❌ Error backing up appcast2.xml: \(error)")
            exit(1)
        }
    }

    private func parseAndDownloadFilesFromAppcast() {
        let parser = XMLParser(contentsOf: specificDir.appendingPathComponent("appcast2.xml"))
        let delegate = AppcastXMLParserDelegate(downloadFile: downloadFile, dispatchGroup: dispatchGroup)
        parser?.delegate = delegate
        if !(parser?.parse() ?? false) {
            if let error = parser?.parserError {
                print("❌ Error parsing XML: \(error)")
                exit(1)
            }
        }
    }

    private func cleanup() {
        do {
            print("Removing \(cacheDir.path)")
            try FileManager.default.removeItem(at: cacheDir)
        } catch {
            print("❗️ Failed to remove cache directory \(cacheDir.path): \(error).")
        }
    }

    final class AppcastXMLParserDelegate: NSObject, XMLParserDelegate {
        var currentElement: String = ""
        var enclosureURL: String = ""
        var releaseNotesHTML: String?
        var marketingVersion: String? // e.g. 1.70.0
        var buildNumber: String? // e.g. 104 (but 1.70.0 for old versions before we switched to using integer build number)

        /**
         * This represents the version as indicated in the file name.
         *
         * For old versions, where build number was equal to the marketing version, it's just the marketing version.
         * For new versions, where build number is an integer, it's the marketing version and the build number joined by a dot.
         */
        var currentVersionIdentifier: String? {
            guard let marketingVersion else {
                return nil
            }
            guard let buildNumber, buildNumber != marketingVersion else {
                return marketingVersion
            }
            return [marketingVersion, buildNumber].joined(separator: ".")
        }

        typealias DownloadFileCallback = (URL, URL, URLRequest.CachePolicy, @escaping (Error?) -> Void) -> Void

        private let downloadFile: DownloadFileCallback
        private let dispatchGroup: DispatchGroup

        init(downloadFile: @escaping DownloadFileCallback, dispatchGroup: DispatchGroup) {
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
                    self.downloadFile(url, destinationURL, .returnCacheDataElseLoad) { error in
                        if let error = error {
                            print("❌ Error downloading file: \(error)")
                            exit(1)
                        } else {
                            self.dispatchGroup.leave()
                        }
                    }
                }
            } else if elementName == "item" {
                marketingVersion = nil
                buildNumber = nil
                releaseNotesHTML = nil
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if currentElement == "description" {
                releaseNotesHTML = (releaseNotesHTML ?? "") + string.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if currentElement == "sparkle:shortVersionString" {
                marketingVersion = ((marketingVersion ?? "") + string.trimmingCharacters(in: .whitespacesAndNewlines))
            } else if currentElement == "sparkle:version" {
                buildNumber = ((buildNumber ?? "") + string.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            if elementName == "item" {
                if let releaseNotesHTML = releaseNotesHTML, let versionIdentifier = currentVersionIdentifier {
                    let releaseNotesPath = specificDir.appendingPathComponent("duckduckgo-\(versionIdentifier).html").path
                    do {
                        try releaseNotesHTML.write(toFile: releaseNotesPath, atomically: true, encoding: .utf8)
                    } catch {
                        print("❌ Failed to write release notes: \(error)")
                        exit(1)
                    }
                    print("✅ Release notes for \(versionIdentifier) saved into \(releaseNotesPath)")
                }
            }
        }

        func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
            print("❌ XML Parse Error: \(parseError)")
            exit(1)
        }
    }
}

// MARK: - Handling of Release Notes

func handleReleaseNotesHTML(path: String, updatesDirectoryURL: URL, dmgURL: URL) {
    // Copy release notes file and rename it to match the dmg filename
    let releaseNotesURL = URL(fileURLWithPath: path)
    let destinationReleaseNotesURL = updatesDirectoryURL.appendingPathComponent(dmgURL.deletingPathExtension().lastPathComponent + ".html")

    do {
        if FileManager.default.fileExists(atPath: destinationReleaseNotesURL.path) {
            try FileManager.default.removeItem(at: destinationReleaseNotesURL)
            print("Old release notes file removed.")
        }

        // Save the converted release notes to the destination file
        try FileManager.default.copyItem(at: releaseNotesURL, to: destinationReleaseNotesURL)
        print("✅ New release notes HTML file copied to the updates directory.")

    } catch {
        print("❌ Failed to copy and convert release notes HTML file: \(error).")
        exit(1)
    }
}

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
        print("✅ New release notes file copied to the updates directory and converted to HTML.")

    } catch {
        print("❌ Failed to copy and convert release notes file: \(error).")
        exit(1)
    }
}

func getVersionNumberFromDMGFileName(dmgURL: URL) -> String {
    // Extract version number from DMG file name
    let filename = dmgURL.lastPathComponent
    let components = filename.components(separatedBy: "-")
    guard components.count >= 2 else {
        print("❌ Invalid DMG file name format. Expected 'duckduckgo-X.Y.Z.B.dmg'")
        exit(1)
    }
    let versionWithExtension = components[1]
    let versionComponents = versionWithExtension.components(separatedBy: ".dmg")
    let versionSubcomponents = versionComponents[0].split(separator: ".").map(String.init)
    if versionSubcomponents.count > 3 {
        return String(versionSubcomponents[3])
    }
    return String(versionComponents[0])
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
        print("❌ Failed to copy dmg file: \(error).")
        return nil
    }
}

func findDMG(for versionIdentifier: String, in dir: URL) -> String? {
    let fileURL = dir.appending(component: "duckduckgo-\(versionIdentifier).dmg")
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory), isDirectory.boolValue == false else {
        return nil
    }
    return fileURL.lastPathComponent
}

// MARK: - Processing of Appcast

func processAppcast(removing versionNumber: String, appcastFilePath: URL) -> Bool {
    guard let appcastContent = readAppcastContent(from: appcastFilePath) else {
        print("❌ Failed to read the appcast file.")
        return false
    }
    guard let modifiedAppcastContent = removeVersionFromAppcast(versionNumber, appcastContent: appcastContent) else {
        print("❌ Failed to remove version #\(versionNumber) from the appcast.")
        return false
    }
    writeAppcastContent(modifiedAppcastContent, to: appcastFilePath)
    return true
}

func readAppcastContent(from filePath: URL) -> String? {
    try? String(contentsOf: filePath, encoding: .utf8)
}

func removeVersionFromAppcast(_ version: String, appcastContent: String) -> String? {
    let pattern = "(<item>.*?<sparkle:version>\(version)</sparkle:version>.*?</item>)"

    guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators),
          let startMatch = regex.firstMatch(in: appcastContent, range: NSRange(appcastContent.startIndex..., in: appcastContent)),
          let endRange = appcastContent.range(of: "</item>", options: [], range: Range(startMatch.range, in: appcastContent)!)
    else {
        print("❌ Failed to match version \(version) in the appcast content.")
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
        print("❌ Failed to write the modified appcast file: \(error).")
        exit(1)
    }
}

// MARK: - Generating of New Appcast

func runGenerateAppcast(with versionNumber: String, channel: String? = nil, rolloutInterval: String? = nil, keyFile: String? = nil) {
    let maximumVersions = "2"
    let maximumDeltas = "2"

    var commandComponents: [String] = []
    commandComponents.append("generate_appcast")
    commandComponents.append("--versions \(versionNumber)")
    commandComponents.append("--maximum-versions \(maximumVersions)")
    commandComponents.append("--maximum-deltas \(maximumDeltas)")
    if let keyFile {
        commandComponents.append("--ed-key-file \(keyFile)")
    }

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
        print("❌ generate_appcast command failed with exit code \(task.terminationStatus).")
        exit(1)
    }

    print("✅ generate_appcast command executed successfully.")

    // Verify presense of old builds
    if !verifyAppcastContainsBuild(lastCatalinaBuildVersion, in: appcastFilePath) {
        print("❌ Error: Appcast does not contain the build (\(lastCatalinaBuildVersion)).")
        exit(1)
    }

    // Get and save the diff
    let diffResult = shell("diff", "-u", backupAppcastFilePath, appcastFilePath.path)
    let diffFilePath = specificDir.appendingPathComponent("appcast_diff.txt").path
    do {
        try diffResult.write(toFile: diffFilePath, atomically: true, encoding: .utf8)
        print("Differences in appcast file saved to: \(diffFilePath)")
    } catch {
        print("❗️ Error writing diff to file: \(error)")
    }

    // Move files back to the original location
    moveFiles(from: specificDir.appendingPathComponent("old_updates"), to: specificDir)
    print("Old update files moved back to \(specificDir.path)")

    if !isCI {
        // Open specific directory in Finder
        shell("open", specificDir.path)
    }
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
        print("❌ Failed to move files from \(sourceDir.path) to \(destinationDir.path): \(error).")
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
        print("❌ Failed to read the appcast file.")
        return false
    }

    let buildString = "<sparkle:version>\(buildVersion)</sparkle:version>"
    return appcastContent.contains(buildString)
}

// MARK: - Helpers

/// pretty-print number of bytes (61,9 MB)
func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .file
    formatter.zeroPadsFractionDigits = true
    return formatter.string(fromByteCount: bytes)
}

enum ProgressSpinner: Int, CustomStringConvertible {
    case a, b, c, d
    var description: String {
        switch self {
        case .a: "-"
        case .b: "\\"
        case .c: "|"
        case .d: "/"
        }
    }
}

/// draws animated progress bar: [=========---------------------] / (19,8 MB of 61,9 MB)
var progressSpinnerState: ProgressSpinner!
func updateProgress(_ total: Int64, received: Int64) {
    guard total > 0 else { return }

    if progressSpinnerState == nil {
        progressSpinnerState = ProgressSpinner.a
        print("")
    }

    let max: Double = 30
    let progress = Double(received) / Double(total)
    let filled = Int(max * progress)
    let remaining = Int(max) - filled

    print("\r  [" + String(repeating: "=", count: filled) + String(repeating: "-", count: remaining) + "]",
          progressSpinnerState.description,
          "(" + formatBytes(received),
          "of",
          formatBytes(total) + ")",
          "           ", // overwrite last progress
          terminator: "")
    print("\r", terminator: "") // caret return for other log messages
    fflush(stdout)

    progressSpinnerState = .init(rawValue: progressSpinnerState.rawValue + 1) ?? .a
}

extension URL {
    var isDirectory: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
}

// swiftlint:enable line_length
// swiftlint:enable function_body_length
