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

// https://github.com/WebKit/webkit/blob/main/Source/WebKit/UIProcess/API/Cocoa/_WKDownloadDelegate.h
@objc protocol WebKitDownloadDelegate: NSObjectProtocol {
    // swiftlint:disable identifier_name
    @objc func _downloadDidStart(_ download: WebKitDownload)

    @objc func _download(_ download: WebKitDownload, didReceiveResponse response: URLResponse)
    @objc func _download(_ download: WebKitDownload,
                         decideDestinationWithSuggestedFilename suggestedFilename: String?,
                         completionHandler: @escaping (/*allowOverwrite:*/ Bool, /*destination:*/ String?) -> Void)

    @objc func _download(_ download: WebKitDownload, didWriteData bytesWritten: UInt64, totalBytesWritten: UInt64, totalBytesExpectedToWrite: UInt64)

    @objc func _downloadDidFinish(_ download: WebKitDownload)
    @objc func _downloadDidCancel(_ download: WebKitDownload)
    @objc func _download(_ download: WebKitDownload, didFailWithError error: Error)

    @objc func _download(_ download: WebKitDownload,
                         didReceiveAuthenticationChallenge challenge: URLAuthenticationChallenge,
                         completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    // swiftlint:enable identifier_name
}

// https://developer.limneos.net/?ios=11.0&framework=WebKit.framework&header=_WKDownload.h
@objc protocol WebKitDownload: NSObjectProtocol {
}
@objc private protocol ObjCWebKitDownload {
    var request: URLRequest? { get }
    var originatingWebView: WKWebView? { get }
    func cancel()
}

extension WebKitDownload {

    var request: URLRequest? {
        guard self.responds(to: #selector(getter: ObjCWebKitDownload.request)) else {
            assertionFailure("WebKitDownload does not respond to selector \"request\"")
            return nil
        }
        return self.perform(#selector(getter: ObjCWebKitDownload.request))?
            .takeUnretainedValue() as? URLRequest
    }

    var originatingWebView: WKWebView? {
        guard self.responds(to: #selector(getter: ObjCWebKitDownload.originatingWebView)) else {
            assertionFailure("WebKitDownload does not respond to selector \"request\"")
            return nil
        }
        return self.perform(#selector(getter: ObjCWebKitDownload.originatingWebView))?
            .takeUnretainedValue() as? WKWebView
    }

    func cancel() {
        guard self.responds(to: #selector(ObjCWebKitDownload.cancel)) else {
            assertionFailure("WebKitDownload does not respond to selector \"cancel\"")
            return
        }
        self.perform(#selector(ObjCWebKitDownload.cancel))
    }

}
