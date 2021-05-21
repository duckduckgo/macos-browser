//
//  URLRequestDownloadTask.swift
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
import os

final class URLRequestDownloadTask: FileDownloadTask {

    private var session: URLSession?
    private var sessionDelegateWrapper: WeakURLRequestDownloadTaskWrapper?
    private let request: URLRequest
    private var task: URLSessionTask?

    private var downloadedFileLocationCancellable: AnyCancellable?
    private var downloadedFileBytesWrittenCancellable: AnyCancellable?
    static private let progressThrottleQueue = DispatchQueue(label: "URLRequestDownloadTask.progressThrottleQueue", qos: .background)

    static let downloadExtension = "duckDownload"

    private var responseSuggestedFilename: String?

    private enum State {
        case initial
        case waitingForDownloadLocation
        case downloadLocationChosen
        case finished
    }
    private var state: State = .initial

    override var suggestedFilename: String {
        guard let responseSuggestedFilename = responseSuggestedFilename,
              !responseSuggestedFilename.isEmpty
        else {
            return super.suggestedFilename
        }
        return responseSuggestedFilename
    }

    private var downloadedFile: DownloadedFile? {
        didSet {
            guard let downloadedFile = downloadedFile else { return }
            downloadedFileLocationCancellable = downloadedFile.$url.sink { [weak self] url in
                guard let url = url else {
                    // .download file removed: cancel download
                    self?.progress.unpublishIfNeeded()
                    self?.cancel()
                    return
                }
                self?.progress.fileURL = url
            }
            downloadedFileBytesWrittenCancellable = downloadedFile.$bytesWritten
                .throttle(for: 0.3, scheduler: Self.progressThrottleQueue, latest: true)
                .map(Int64.init)
                .weakAssign(to: \.completedUnitCount, on: self.progress)
        }
    }

    init(download: FileDownload, session: URLSession? = nil, request: URLRequest) {
        self.session = session
        self.request = request

        super.init(download: download)
    }

    override func start() {
        sessionDelegateWrapper = WeakURLRequestDownloadTaskWrapper(task: self)
        session = URLSession(configuration: session?.configuration ?? .default,
                             delegate: sessionDelegateWrapper,
                             delegateQueue: nil)
        task = session?.dataTask(with: request)
        self.progress.fileDownloadingSourceURL = request.url

        task?.resume()
    }

    override func cancel() {
        self.task?.cancel()
    }

    // Local Save URL and Type chosen using Save Panel or automatically
    override func localFileURLCompletionHandler(localURL: URL?, fileType: UTType?) {
        dispatchPrecondition(condition: .onQueue(.main))

        guard let url = localURL,
              let task = self.task,
              let downloadedFile = self.downloadedFile
        else {
            self.task?.cancel()
            self.finish(with: .failure(.cancelled))
            return
        }

        switch task.state {
        case .completed:
            // move to final destination when already downloaded to temp location
            do {
                let finalURL = try downloadedFile.move(to: url, incrementingIndexIfExists: true)
                self.finish(with: .success(finalURL))
            } catch {
                self.finish(with: .failure(.failedToMoveFileToDownloads))
            }

        case .running, .suspended:
            // move to Downloads folder with .duckDownload extension if download is still in progress
            let downloadURL = url.appendingPathExtension(Self.downloadExtension)
            let ext = url.pathExtension + (url.pathExtension.isEmpty ? "" : ".") + Self.downloadExtension
            do {
                _=try downloadedFile.move(to: downloadURL, incrementingIndexIfExists: true, pathExtension: ext)
            } catch {
                task.cancel()
                self.finish(with: .failure(.failedToMoveFileToDownloads))
                return
            }

            self.state = .downloadLocationChosen
            self.progress.publishIfNotPublished()

        case .canceling:
            break
        @unknown default:
            break
        }
    }

    override func _finish(with result: Result<URL, FileDownloadError>) {
        guard state != .finished else { return }
        self.state = .finished

        if self.downloadedFile != nil {
            self.progress.publishIfNotPublished()
        }

        super._finish(with: result)

        if case .failure = result {
            self.downloadedFile?.delete()
        }
        self.downloadedFile = nil
    }
    
    // MARK: - URLSessionDataDelegate

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {

        // start download to temp location before final location is chosen
        let downloadLocation = DownloadPreferences().selectedDownloadLocation
        // find appropriate temp folder for final destination URL
        let tempDir = FileManager.default.temporaryDirectory(appropriateFor: downloadLocation)
        let tempURL = tempDir.appendingPathComponent(.uniqueFilename())

        self.downloadedFile = try? DownloadedFile(url: tempURL)
        self.responseSuggestedFilename = response.suggestedFilename
        self.fileTypes = response.mimeType.flatMap(UTType.init(mimeType:)).map { [$0] }
        self.progress.totalUnitCount = response.expectedContentLength

        // fire completionHandler asynchronously to satisfy URLSession
        DispatchQueue.main.async {
            completionHandler(.allow)

            // and request final destination URL using Save Panel or automatically
            self.state = .waitingForDownloadLocation
            self.queryDestinationURL()
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.downloadedFile?.write(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            if (error as? URLError)?.code == URLError.cancelled {
                self.finish(with: .failure(.cancelled))
            } else {
                self.finish(with: .failure(.failedToCompleteDownloadTask(underlyingError: error)))
            }

        } else {
            do {
                // only move file to final destination if SavePanel did complete by the moment
                // otherwise move and finish the task in the localFileURLCompletionHandler
                guard case .downloadLocationChosen = DispatchQueue.main.nowOrSync({ self.state }) else {
                    return
                }
                guard let downloadedFile = self.downloadedFile,
                      // .download file may have been renamed: respect this new name and just drop .download ext
                      let url = downloadedFile.url?.path.drop(suffix: "." + Self.downloadExtension)
                else {
                    throw FileDownloadError.failedToMoveFileToDownloads
                }
                
                let finalURL = try downloadedFile.move(to: URL(fileURLWithPath: url), incrementingIndexIfExists: true)

                self.finish(with: .success(finalURL))

            } catch {
                self.finish(with: .failure(.failedToMoveFileToDownloads))
            }
        }
    }

}

// URLSession strongly holds its delegate
fileprivate final class WeakURLRequestDownloadTaskWrapper: NSObject, URLSessionDataDelegate {
    weak var task: URLRequestDownloadTask?

    init(task: URLRequestDownloadTask?) {
        self.task = task
    }

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.task?.urlSession(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.task?.urlSession(session, dataTask: dataTask, didReceive: data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        self.task?.urlSession(session, task: task, didCompleteWithError: error)
    }

}
