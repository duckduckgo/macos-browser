//
//  WebKitDownloadDelegate.swift
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
import WebKit
import Combine

protocol FileDownloadManagerProtocol {
    func startDownload(_ request: FileDownloadRequest,
                       delegate: FileDownloadManagerDelegate?,
                       postflight: FileDownloadPostflight?) -> FileDownloadTask?
}

extension FileDownloadManager: FileDownloadManagerProtocol {}

final class WebKitDownloadDelegate: NSObject {

    static let shared = WebKitDownloadDelegate()
    private let downloadManager: FileDownloadManagerProtocol
    private let postflight: FileDownloadPostflight

    private var tasks = [NSObject: WebKitDownloadTaskProtocol]()
    private var cancellables = [NSObject: AnyCancellable]()

    init(downloadManager: FileDownloadManagerProtocol = FileDownloadManager.shared,
         postflightAction: FileDownloadPostflight = .reveal) {
        self.downloadManager = downloadManager
        self.postflight = postflightAction
    }

    private func setTask(_ task: WebKitDownloadTaskProtocol?,
                         cancellable: AnyCancellable?,
                         for download: WebKitDownload) {
        // swiftlint:disable force_cast
        self.tasks[download as! NSObject] = task
        self.cancellables[download as! NSObject] = cancellable
        // swiftlint:enable force_cast
    }

    private func task(for download: WebKitDownload) -> WebKitDownloadTaskProtocol? {
        return self.tasks[download as! NSObject] // swiftlint:disable:this force_cast
    }

}

// swiftlint:disable identifier_name
// https://github.com/WebKit/webkit/blob/main/Source/WebKit/UIProcess/API/Cocoa/_WKDownloadDelegate.h
extension WebKitDownloadDelegate {

    @objc func _downloadDidStart(_ download: WebKitDownload) {
        let delegate = download.originatingWebView?.uiDelegate as? FileDownloadManagerDelegate
        assert(delegate != nil, "webView.uiDelegate does not conform to FileDownloadManagerDelegate")

        guard let task = downloadManager.startDownload(FileDownload.wkDownload(download),
                                                       delegate: delegate,
                                                       postflight: postflight) as? WebKitDownloadTaskProtocol
        else {
            assertionFailure("Task returned by DownloadManager should conform to WebKitDownloadTaskProtocol")
            return
        }

        let cancellable = task.output.receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setTask(nil, cancellable: nil, for: download)
        } receiveValue: { _ in }

        self.setTask(task, cancellable: cancellable, for: download)
    }

    @objc func _download(_ download: WebKitDownload, didReceiveResponse response: URLResponse) {
        task(for: download)?.download(download, didReceiveResponse: response)
    }

    @objc func _download(_ download: WebKitDownload,
                         didWriteData bytesWritten: UInt64,
                         totalBytesWritten: UInt64,
                         totalBytesExpectedToWrite: UInt64) {
        task(for: download)?.download(download,
                                      didWriteData: bytesWritten,
                                      totalBytesWritten: totalBytesWritten,
                                      totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }

    @objc func _download(_ download: WebKitDownload,
                         decideDestinationWithSuggestedFilename suggestedFilename: String?,
                         completionHandler: @escaping (Bool, String?) -> Void) {
        task(for: download)?.download(download,
                                      decideDestinationWithSuggestedFilename: suggestedFilename,
                                      completionHandler: completionHandler)
    }

    @objc func _downloadDidFinish(_ download: WebKitDownload) {
        task(for: download)?.downloadDidFinish(download)
    }

    @objc func _downloadDidCancel(_ download: WebKitDownload) {
        task(for: download)?.downloadDidCancel(download)
    }

    @objc func _download(_ download: WebKitDownload, didFailWithError error: Error) {
        task(for: download)?.download(download, didFailWithError: error)
    }

    @objc func _download(_ download: WebKitDownload,
                         didReceiveAuthenticationChallenge challenge: URLAuthenticationChallenge,
                         completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        task(for: download)?.download(download,
                                      didReceiveAuthenticationChallenge: challenge,
                                      completionHandler: completionHandler)
    }

}
// swiftlint:enable identifier_name
