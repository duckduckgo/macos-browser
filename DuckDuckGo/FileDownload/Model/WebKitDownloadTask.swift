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
import WebKit

final class WebKitDownloadTask: FileDownloadTask {

    static let downloadExtension = "duckload"

    private let wkDownload: WebKitDownload

    private var wkSuggestedFilename: String?
    override var suggestedFilename: String {
        guard let wkSuggestedFilename = wkSuggestedFilename,
              !wkSuggestedFilename.isEmpty
        else {
            return super.suggestedFilename
        }
        return wkSuggestedFilename
    }

    private var decideDestinationCompletionHandler: ((URL?) -> Void)?
    private var tempURL: URL?
    private var destinationURL: URL?

    private var cancellables = Set<AnyCancellable>()

    init(download: WebKitDownload, promptForLocation: Bool) {
        self.wkDownload = download
        super.init(download: FileDownload.wkDownload(download, promptForLocation: promptForLocation))
        download.downloadDelegate = self
    }

    override func start() {
        self.progress.fileDownloadingSourceURL = wkDownload.downloadRequest?.url
        self.wkDownload.getProgress { [weak self] progress in
            guard let self = self else { return }
            
            progress?.publisher(for: \.totalUnitCount)
                .weakAssign(to: \.totalUnitCount, on: self.progress)
                .store(in: &self.cancellables)
            progress?.publisher(for: \.completedUnitCount)
                .weakAssign(to: \.completedUnitCount, on: self.progress)
                .store(in: &self.cancellables)
        }
    }

    override func localFileURLCompletionHandler(localURL: URL?, fileType: UTType?) {
        dispatchPrecondition(condition: .onQueue(.main))

        do {
            struct ThrowableError: Error {}
            guard let localURL = localURL else { throw URLError(.cancelled) }

            var downloadURL = localURL.appendingPathExtension(Self.downloadExtension)
            let ext = localURL.pathExtension + (localURL.pathExtension.isEmpty ? "" : ".") + Self.downloadExtension

            // create temp file and move to Downloads folder with .duckload extension increasing index if needed
            let fm = FileManager.default
            let tempURL = fm.temporaryDirectory(appropriateFor: localURL).appendingPathComponent(.uniqueFilename())
            fm.createFile(atPath: tempURL.path, contents: nil, attributes: nil)
            do {
                downloadURL = try fm.moveItem(at: tempURL, to: downloadURL, incrementingIndexIfExists: true, pathExtension: ext)
                // remove temp item and let WebKit download the file
                try? fm.removeItem(at: downloadURL)
            } catch CocoaError.fileWriteNoPermission {
                downloadURL = localURL
            }

            self.tempURL = downloadURL
            self.destinationURL = localURL

            self.progress.fileURL = downloadURL
            self.progress.publishIfNotPublished()

            self.decideDestinationCompletionHandler?(downloadURL)

        } catch {
            self.wkDownload.cancel()
            self.finish(with: .failure(.cancelled))
            self.decideDestinationCompletionHandler?(nil)
        }
    }

    override func cancel() {
        wkDownload.cancel()
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
            self.fileTypes = UTType(mimeType: mimeType).map { [$0] }
        }
        self.wkSuggestedFilename = suggestedFilename
        self.decideDestinationCompletionHandler = completionHandler
        self.queryDestinationURL()
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
        try? tempURL.map(FileManager.default.removeItem(at:))
        if (error as? URLError)?.code == URLError.cancelled {
            self.finish(with: .failure(.cancelled))
        } else {
            self.finish(with: .failure(.failedToCompleteDownloadTask(underlyingError: error)))
        }
    }

}
