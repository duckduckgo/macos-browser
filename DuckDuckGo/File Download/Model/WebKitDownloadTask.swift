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

import Navigation
import Combine
import Foundation
import WebKit

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

    private(set) var suggestedFilename: String?
    private(set) var suggestedFileType: UTType?

    struct FileLocation: Equatable {
        /// Desired local destination file URL used to display download location
        var destinationURL: URL?
        /// Temporary  (.duckload)  file URL; set to nil when download completes
        var tempURL: URL?
    }

    @Published private(set) var location: FileLocation {
        didSet {
            guard let tempURL = location.tempURL else { return }

            self.progress.fileURL = tempURL
            self.progress.publishIfNotPublished()
        }
    }

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

    var originalRequest: URLRequest? {
        download.originalRequest
    }
    var originalWebView: WKWebView? {
        download.webView
    }

    init(download: WebKitDownload, promptForLocation: Bool, destinationURL: URL?, tempURL: URL?, postflight: FileDownloadManager.PostflightAction? = .none) {

        self.download = download
        self.progress = Progress(totalUnitCount: -1)
        self.shouldPromptForLocation = promptForLocation
        self.location = .init(destinationURL: destinationURL, tempURL: tempURL)
        self.postflight = postflight
        super.init()

        download.delegate = self

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
        if let progress = (self.download as? ProgressReporting)?.progress {
            progress.publisher(for: \.totalUnitCount)
                .assign(to: \.totalUnitCount, onWeaklyHeld: self.progress)
                .store(in: &self.cancellables)
            progress.publisher(for: \.completedUnitCount)
                .assign(to: \.completedUnitCount, onWeaklyHeld: self.progress)
                .store(in: &self.cancellables)
        }
    }

    private func localFileURLCompletionHandler(localURL: URL?, fileType: UTType?) {
        dispatchPrecondition(condition: .onQueue(.main))

        do {
            guard let localURL = localURL,
                  let completionHandler = self.decideDestinationCompletionHandler
            else { throw URLError(.cancelled) }

            let downloadURL = try self.downloadURL(for: localURL)
            self.location = .init(destinationURL: localURL, tempURL: downloadURL)

            completionHandler(downloadURL)

        } catch {
            self.download.cancel()
            self.finish(with: .failure(.failedToCompleteDownloadTask(underlyingError: URLError(.cancelled), resumeData: nil)))
            self.decideDestinationCompletionHandler?(nil)
        }
    }

    private func downloadURL(for localURL: URL) throws -> URL {
        var downloadURL = self.location.tempURL ?? localURL.appendingPathExtension(Self.downloadExtension)
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
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.cancel()
            }
            return
        }
        download.cancel { [weak self] _ in
            self?.downloadDidFail(with: URLError(.cancelled), resumeData: nil)
        }
    }

    private func finish(with result: Result<URL, FileDownloadError>) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let fulfill = self.fulfill else {
            // already finished
            return
        }

        if case .success(let url) = result {
            let newLocation = FileLocation(destinationURL: url, tempURL: nil)
            if self.location != newLocation {
                self.location = newLocation
            }
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

    private func downloadDidFail(with error: Error, resumeData: Data?) {
        if resumeData == nil,
           let tempURL = location.tempURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
        self.finish(with: .failure(.failedToCompleteDownloadTask(underlyingError: error, resumeData: resumeData)))
    }

    deinit {
        dispatchPrecondition(condition: .onQueue(.main))
        self.progress.unpublishIfNeeded()
        assert(fulfill == nil, "FileDownloadTask is deallocated without finish(with:) been called")
    }

}

extension WebKitDownloadTask: WebKitDownloadDelegate {}
@available(macOS 11.3, *) // objc does‘t care about availability
@objc extension WebKitDownloadTask {

    func download(_: WKDownload,
                  decideDestinationUsing response: URLResponse,
                  suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {

        guard let delegate = delegate else {
            assertionFailure("WebKitDownloadTask: delegate is gone")
            completionHandler(nil)
            return
        }

        if var mimeType = response.mimeType {
            // drop ;charset=.. from "text/plain;charset=utf-8"
            if let charsetRange = mimeType.range(of: ";charset=") {
                mimeType = String(mimeType[..<charsetRange.lowerBound])
            }
            self.suggestedFileType = UTType(mimeType: mimeType)
        }
        if self.progress.totalUnitCount <= 0 {
            self.progress.totalUnitCount = response.expectedContentLength
        }

        var suggestedFilename = suggestedFilename
        // sometimes suggesteFilename has an extension appended to already present URL file extension
        // e.g. feed.xml.rss for www.domain.com/rss.xml
        if let urlSuggestedFilename = response.url?.suggestedFilename,
           !(urlSuggestedFilename as NSString).pathExtension.isEmpty,
           suggestedFilename.hasPrefix(urlSuggestedFilename) {
            suggestedFilename = urlSuggestedFilename
        }

        self.suggestedFilename = suggestedFilename
        self.decideDestinationCompletionHandler = completionHandler

        if let destinationURL = location.destinationURL {
            self.localFileURLCompletionHandler(localURL: destinationURL, fileType: self.suggestedFileType)
        } else {
            delegate.fileDownloadTaskNeedsDestinationURL(self,
                                                         suggestedFilename: suggestedFilename,
                                                         completionHandler: self.localFileURLCompletionHandler)
        }
    }

    func download(_: WKDownload,
                  willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest,
                  decisionHandler: @escaping (WKDownload.RedirectPolicy) -> Void) {
        decisionHandler(.allow)
    }

    func download(_ download: WKDownload,
                  didReceive challenge: URLAuthenticationChallenge,
                  completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        download.webView?.navigationDelegate?.webView?(download.webView!, didReceive: challenge, completionHandler: completionHandler) ?? {
            completionHandler(.performDefaultHandling, nil)
        }()
    }

    func downloadDidFinish(_: WKDownload) {
        guard var destinationURL = location.destinationURL else {
            self.finish(with: .failure(.failedToMoveFileToDownloads))
            return
        }

        if let tempURL = location.tempURL, tempURL != destinationURL {
            do {
                destinationURL = try FileManager.default.moveItem(at: tempURL, to: destinationURL, incrementingIndexIfExists: true)
            } catch {
                destinationURL = tempURL
            }
        }

        self.finish(with: .success(destinationURL))
    }

    func download(_: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloadDidFail(with: error, resumeData: resumeData)
    }

    func download(_: WKDownload, didReceiveDataWithLength length: UInt64) {
        self.progress.completedUnitCount += Int64(length)
    }

}

extension WebKitDownloadTask {

    var didChooseDownloadLocationPublisher: AnyPublisher<URL, FileDownloadError> {
        Publishers.Merge(
            $location
            // waiting for the download location to be chosen
                .compactMap { $0.destinationURL }
                .mapError { (_: Never) -> FileDownloadError in }
                .eraseToAnyPublisher(),
            // downloadTask.output Publisher will complete with an error if cancelled
            output.eraseToAnyPublisher()
        )
        // complete the Publisher when the location is chosen
        .first()
        .eraseToAnyPublisher()
    }

}
