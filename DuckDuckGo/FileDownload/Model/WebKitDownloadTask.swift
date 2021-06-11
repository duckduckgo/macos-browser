//
//  WebKitDownloadTask.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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
import Combine

enum FileDownloadError: Error {
    case cancelled

    case restartResumeNotSupported
    case failedToCreateTemporaryDir
    case failedToMoveFileToDownloads
    case failedToCompleteDownloadTask(underlyingError: Error, resumeData: Data?)
}

protocol WebKitDownloadTaskDelegate: AnyObject {
    func fileDownloadTaskNeedsDestinationURL(_ task: WebKitDownloadTask,
                                             suggestedFilename: String,
                                             completionHandler: @escaping (URL?, UTType?) -> Void)
    func fileDownloadTask(_ task: WebKitDownloadTask, didFinishWith result: Result<URL, FileDownloadError>)
}

/// WKDownload wrapper managing Finder File Progress and coordinating file URLs
final class WebKitDownloadTask: NSObject, ProgressReporting {

    static let downloadExtension = "duckload"

    let progress: Progress
    let shouldPromptForLocation: Bool
    /// Action that should be performed on file after it's downloaded
    var postflight: FileDownloadManager.PostflightAction?
    /// Desired local destination file URL used to display download location
    @PublishedAfter private(set) var destinationURL: URL?
    /// File Type used for File Icon generation
    @PublishedAfter private(set) var fileType: UTType?

    private lazy var future: Future<URL, FileDownloadError> = {
        dispatchPrecondition(condition: .onQueue(.main))
        let future = Future<URL, FileDownloadError> { self.fulfill = $0 }
        assert(self.fulfill != nil)
        return future
    }()
    private var fulfill: Future<URL, FileDownloadError>.Promise?
    /// Task completion Publisher outputting destination URL or failure Error with Resume Data if available
    var output: AnyPublisher<URL, FileDownloadError> { future.eraseToAnyPublisher() }

    private weak var delegate: WebKitDownloadTaskDelegate?

    private let download: WebKitDownload
    private var cancellables = Set<AnyCancellable>()

    private var decideDestinationCompletionHandler: ((URL?) -> Void)?
    private var tempURL: URL?

    init(download: WebKitDownload, promptForLocation: Bool, postflight: FileDownloadManager.PostflightAction?) {
        self.download = download
        self.progress = Progress(totalUnitCount: -1)
        self.shouldPromptForLocation = promptForLocation
        self.postflight = postflight
        super.init()

        download.downloadDelegate = self

        progress.fileOperationKind = .downloading
        progress.kind = .file
        progress.completedUnitCount = 0

        progress.isPausable = false
        progress.isCancellable = true
        progress.cancellationHandler = { [weak self] in
            self?.cancel()
        }
    }

    func start(delegate: WebKitDownloadTaskDelegate) {
        _=future
        self.delegate = delegate
        start()
    }

    private func start() {
        self.progress.fileDownloadingSourceURL = download.originalRequest?.url
        self.download.getProgress { [weak self] progress in
            guard let self = self else { return }

            progress?.publisher(for: \.totalUnitCount)
                .weakAssign(to: \.totalUnitCount, on: self.progress)
                .store(in: &self.cancellables)
            progress?.publisher(for: \.completedUnitCount)
                .weakAssign(to: \.completedUnitCount, on: self.progress)
                .store(in: &self.cancellables)
        }
    }

    func localFileURLCompletionHandler(localURL: URL?, fileType: UTType?) {
        dispatchPrecondition(condition: .onQueue(.main))

        do {
            guard let localURL = localURL,
                  let completionHandler = self.decideDestinationCompletionHandler
            else { throw URLError(.cancelled) }

            let downloadURL = try self.downloadURL(for: localURL)

            self.tempURL = downloadURL
            self.destinationURL = localURL

            self.progress.fileURL = downloadURL
            self.progress.publishIfNotPublished()

            completionHandler(downloadURL)

        } catch {
            self.download.cancel()
            self.finish(with: .failure(.cancelled))
            self.decideDestinationCompletionHandler?(nil)
        }
    }

    private func downloadURL(for localURL: URL) throws -> URL {
        var downloadURL = localURL.appendingPathExtension(Self.downloadExtension)
        let ext = localURL.pathExtension + (localURL.pathExtension.isEmpty ? "" : ".") + Self.downloadExtension

        // create temp file and move to Downloads folder with .duckload extension increasing index if needed
        let fm = FileManager.default
        let tempURL = fm.temporaryDirectory(appropriateFor: localURL).appendingPathComponent(.uniqueFilename())
        do {
            guard fm.createFile(atPath: tempURL.path, contents: nil, attributes: nil) else {
                throw CocoaError(.fileWriteNoPermission)
            }
            downloadURL = try fm.moveItem(at: tempURL, to: downloadURL, incrementingIndexIfExists: true, pathExtension: ext)
        } catch CocoaError.fileWriteNoPermission {
            try? fm.removeItem(at: tempURL)
            downloadURL = localURL
            // make sure we can write to the download location
            guard fm.createFile(atPath: downloadURL.path, contents: nil, attributes: nil) else {
                throw CocoaError(.fileWriteNoPermission)
            }
        }

        // remove temp item and let WebKit download the file
        try? fm.removeItem(at: downloadURL)

        return downloadURL
    }

    func cancel() {
        download.cancel()
    }

    private func finish(with result: Result<URL, FileDownloadError>) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let fulfill = self.fulfill else {
            // already finished
            return
        }

        if case .success(let url) = result {
            if progress.fileURL != url {
                progress.fileURL = url
            }
            if self.progress.totalUnitCount == -1 {
                self.progress.totalUnitCount = 1
            }
            self.progress.completedUnitCount = self.progress.totalUnitCount
        }

        self.progress.unpublishIfNeeded()

        self.delegate?.fileDownloadTask(self, didFinishWith: result)
        self.fulfill = nil
        fulfill(result)
    }

    deinit {
        self.progress.unpublishIfNeeded()
        assert(fulfill == nil, "FileDownloadTask is deallocated without finish(with:) been called")
    }

}

extension WebKitDownloadTask: WebKitDownloadDelegate {

    func download(_ download: WebKitDownload,
                  decideDestinationUsing response: URLResponse?,
                  suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {

        if var mimeType = response?.mimeType {
            // drop ;charset=.. from "text/plain;charset=utf-8"
            if let charsetRange = mimeType.range(of: ";charset=") {
                mimeType = String(mimeType[..<charsetRange.lowerBound])
            }
            self.fileType = UTType(mimeType: mimeType)
        }

        self.decideDestinationCompletionHandler = completionHandler
        delegate?.fileDownloadTaskNeedsDestinationURL(self,
                                                      suggestedFilename: suggestedFilename,
                                                      completionHandler: self.localFileURLCompletionHandler)
    }

    func downloadDidFinish(_ download: WebKitDownload) {
        guard var destinationURL = destinationURL else {
            self.finish(with: .failure(.failedToMoveFileToDownloads))
            return
        }

        if let tempURL = tempURL, tempURL != destinationURL {
            do {
                destinationURL = try FileManager.default.moveItem(at: tempURL, to: destinationURL, incrementingIndexIfExists: true)
            } catch {
                destinationURL = tempURL
            }
        }

        self.finish(with: .success(destinationURL))
    }

    func download(_ download: WebKitDownload, didFailWithError error: Error, resumeData: Data?) {
        if resumeData == nil,
           let tempURL = tempURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
        if (error as? URLError)?.code == URLError.cancelled {
            self.finish(with: .failure(.cancelled))
        } else {
            self.finish(with: .failure(.failedToCompleteDownloadTask(underlyingError: error,
                                                                     resumeData: resumeData)))
        }
    }

}
