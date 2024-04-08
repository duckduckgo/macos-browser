//
//  SandboxTestTool.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import AppKit
import Combine
import Common
import Foundation

@main
struct SandboxTestTool {
    static func main() {
        SandboxTestToolApp.shared.run()
    }
}

@objc(SandboxTestToolApp)
final class SandboxTestToolApp: NSApplication {

    private var _delegate: SandboxTestToolAppDelegate!

    override init() {
        super.init()

        _delegate = SandboxTestToolAppDelegate()
        self.delegate = _delegate
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

extension FileLogger: FilePresenterLogger {
    func log(_ message: @autoclosure () -> String) {
        log(message(), includeTimestamp: true)
    }
}

final class FileLogger {
    static let shared = FileLogger()

    private init() {}

    private let pid = ProcessInfo().processIdentifier

    private let fileURL: URL = {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("logfile.txt")
    }()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private let queue = DispatchQueue(label: "log queue")
    private lazy var fileHandle: FileHandle = {
        let fileHandle = (try? FileHandle(forWritingTo: fileURL))!
        fileHandle.seekToEndOfFile()
        return fileHandle
    }()

    func log(_ message: String, includeTimestamp: Bool) {
        os_log("%{public}s", message)
        queue.sync {
            let logMessage = includeTimestamp ? "[\(pid)] \(dateFormatter.string(from: Date())): \(message)\n" : (message + "\n")

            fileHandle.write(logMessage.data(using: .utf8)!)
        }
    }

}

final class SandboxTestToolAppDelegate: NSObject, NSApplicationDelegate {

    // uncomment these for logging
// #if CI
    let logger = OSLog.disabled
// #else
//    let logger = FileLogger.shared
// #endif

    override init() {
        logger.log("\n\n\n🚦 starting…\n")

        super.init()

        DistributedNotificationCenter.default().addObserver(forName: SandboxTestNotification.terminate.name, object: nil, queue: nil, using: terminate)
        DistributedNotificationCenter.default().addObserver(forName: SandboxTestNotification.ping.name, object: nil, queue: nil, using: ping)
        DistributedNotificationCenter.default().addObserver(forName: SandboxTestNotification.openFile.name, object: nil, queue: nil, using: openFile)
        DistributedNotificationCenter.default().addObserver(forName: SandboxTestNotification.openFileWithoutBookmark.name, object: nil, queue: nil, using: openFile)
        DistributedNotificationCenter.default().addObserver(forName: SandboxTestNotification.openBookmarkWithFilePresenter.name, object: nil, queue: nil, using: openBookmarkWithFilePresenter)
        DistributedNotificationCenter.default().addObserver(forName: SandboxTestNotification.closeFilePresenter.name, object: nil, queue: nil, using: closeFilePresenter)

        NSURL.swizzleStopAccessingSecurityScopedResource { [unowned self] url in
            post(.stopAccessingSecurityScopedResourceCalled, with: url.path)
        }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        post(.hello, with: nil)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.log("🚦 didFinishLaunching\n")
    }

    private func ping(_ notification: Notification) {
        logger.log("➡️  ping")
        post(.pong, with: notification.object as? String)
    }

    private func openFile(_ notification: Notification) {
        logger.log("➡️  openFile \(notification.object as? String ?? "<nil>")")
        guard let filePath = notification.object as? String else {
            post(.error, with: "No file path provided")
            return
        }
        openFile(filePath, creatingBookmark: notification.name == SandboxTestNotification.openFile)
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        logger.log("➡️  app.openFile(\"\(filename)\")")
        openFile(filename, creatingBookmark: true)
        return true
    }

    private func openFile(_ filePath: String, creatingBookmark bookmarkNeeded: Bool) {
        let url = URL(fileURLWithPath: filePath)

        let data: String
        do {
            data = try String(contentsOf: url)
        } catch {
            post(.error, with: error.encoded("Error opening file"))
            return
        }

        var bookmark: Data?
        if bookmarkNeeded {
            do {
                bookmark = try url.bookmarkData(options: .withSecurityScope)
            } catch let error as NSError {
                post(.error, with: error.encoded("Error creating bookmark"))
                return
            }
        }

        post(.fileRead, with: FileReadResult(path: filePath, data: data, bookmark: bookmark).encoded())
    }

    private var filePresenters = [URL: FilePresenter]()
    private var filePresenterCancellables = [URL: Set<AnyCancellable>]()

    private func openBookmarkWithFilePresenter(_ notification: Notification) {
        logger.log("📕 openBookmarkWithFilePresenter")
        guard let object = notification.object as? String, let bookmark = Data(base64Encoded: object) else {
            post(.error, with: CocoaError(CocoaError.Code.coderReadCorrupt).encoded("Invalid bookmark data"))
            return
        }
        do {
            let filePresenter = try SandboxFilePresenter(fileBookmarkData: bookmark, logger: logger)
            guard let url = filePresenter.url else { throw NSError(domain: "SandboxTestTool", code: -1, userInfo: [NSLocalizedDescriptionKey: "FilePresenter URL is nil"]) }

            filePresenter.urlPublisher.dropFirst().sink { [unowned self] url in
                post(.fileMoved, with: url?.path)
            }.store(in: &filePresenterCancellables[url, default: []])
            filePresenter.fileBookmarkDataPublisher.dropFirst().sink { [unowned self] fileBookmarkData in
                post(.fileBookmarkDataUpdated, with: fileBookmarkData?.base64EncodedString())
            }.store(in: &filePresenterCancellables[url, default: []])
            self.filePresenters[url] = filePresenter
            logger.log("📗 openBookmarkWithFilePresenter done: \"\(filePresenter.url?.path ?? "<nil>")\"")
        } catch {
            post(.error, with: error.encoded("could not open SandboxFilePresenter"))
        }
    }

    private func closeFilePresenter(_ notification: Notification) {
        guard let path = notification.object as? String else {
            post(.error, with: CocoaError(CocoaError.Code.coderReadCorrupt).encoded("Should provide file path to close Presenter"))
            return
        }
        logger.log("🌂 closeFilePresenter for \(path)")

        let url = URL(fileURLWithPath: path)
        filePresenterCancellables[url] = nil
        filePresenters[url] = nil
    }

    private func terminate(_ notification: Notification) {
        logger.log("😵 terminate\n---------------")
        NSApp.terminate(self)
    }

    private func post(_ name: SandboxTestNotification, with object: String? = nil) {
        logger.log("📮 \(name.rawValue)\(object != nil ? ": \(object!)" : "")")
        DistributedNotificationCenter.default().post(name: .init(name.rawValue), object: object)
    }

}

private extension Error {
    func encoded(_ descr: String? = nil, file: StaticString = #file, line: UInt = #line) -> String {
        let error = self as NSError
        var dict: [String: Any] = [
            UserInfoKeys.errorDomain: error.domain,
            UserInfoKeys.errorCode: error.code
        ].merging(error.userInfo.filter { $0.value is String || $0.value is Int }, uniquingKeysWith: { $1 })
        if let descr {
            dict[UserInfoKeys.errorDescription] = descr
        }
        let json = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
        return String(data: json!, encoding: .utf8)!
    }
}
