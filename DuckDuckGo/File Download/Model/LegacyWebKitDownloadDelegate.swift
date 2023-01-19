//
//  LegacyWebKitDownloadDelegate.swift
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
import Navigation
import WebKit

final class LegacyWebKitDownloadDelegate: NSObject {

    private var downloadDidStart: (url: URL, callback: (WebKitDownload) -> Void)?
    private var responseCache = [NSObject: URLResponse]()

    func registerDownloadDidStartCallback(_ callback: @escaping (WebKitDownload) -> Void, for url: URL) {
        self.downloadDidStart = (url, callback)
    }

}

@available(macOS 11.3, *) // objc doesn‘t care about availability and object types
// https://github.com/WebKit/webkit/blob/main/Source/WebKit/UIProcess/API/Cocoa/_WKDownloadDelegate.h
private extension LegacyWebKitDownloadDelegate {

    @objc func _downloadDidStart(_ download: WKDownload) {
        guard let webView = download.webView, let delegate = webView.navigationDelegate, let url = download.originalRequest?.url else {
            assertionFailure("WebKitDownload webView or delegate is nil")
            return
        }

        if case .some((url: url, callback: let callback)) = self.downloadDidStart {
            self.downloadDidStart = nil
            callback(download)
        } else {
            let selector = NSSelectorFromString("_webView:contextMenuDidCreateDownload:")
            guard delegate.responds(to: selector) else {
                assertionFailure("delegate does not respond to \(selector)")
                return
            }
            delegate.perform(selector, with: webView, with: download)
        }
    }

    @objc func _download(_ download: WKDownload, didReceiveResponse response: URLResponse) {
        self.responseCache[download] = response
    }

    @objc func _download(_ download: WKDownload,
                         decideDestinationWithSuggestedFilename suggestedFilename: String,
                         completionHandler: @escaping (Bool, String?) -> Void) {
        defer {
            self.responseCache[download] = nil
        }
        guard let delegate = download.delegate else {
            assertionFailure("_download:decideDestinationWithSuggestedFilename: delegate not set")
            completionHandler(false, nil)
            return
        }
        guard let response = self.responseCache[download] else {
            completionHandler(false, nil)
            return
        }

        delegate.download(download, decideDestinationUsing: response, suggestedFilename: suggestedFilename) { url in
            completionHandler(false, url?.path)
        }
    }

    @objc func _downloadDidFinish(_ download: WKDownload) {
        download.delegate?.downloadDidFinish?(download)
    }

    @objc func _downloadDidCancel(_ download: WKDownload) {
        download.delegate?.download?(download, didFailWithError: URLError(.cancelled), resumeData: nil)
    }

    @objc func _download(_ download: WKDownload, didFailWithError error: Error) {
        download.delegate?.download?(download, didFailWithError: error, resumeData: nil)
    }

    @objc(_download:didReceiveAuthenticationChallenge:completionHandler:)
    func _download(_ download: WKDownload,
                   didReceive challenge: URLAuthenticationChallenge,
                   completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        download.delegate?.download?(download, didReceive: challenge, completionHandler: completionHandler)
            ?? download.webView?.navigationDelegate?.webView?(download.webView!, didReceive: challenge, completionHandler: completionHandler)
    }

    @objc(_download:didReceiveData:)
    func _download(_ download: WKDownload, didReceiveData length: UInt64) {
        (download.delegate as? WebKitDownloadDelegate)?.download(download, didReceiveDataWithLength: length)
    }

}
