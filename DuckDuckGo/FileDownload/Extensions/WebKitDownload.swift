//
//  WebKitDownload.swift
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

@objc protocol WebKitDownload {
    var downloadRequest: URLRequest? { get }
    var webView: WKWebView? { get }
    var downloadDelegate: WebKitDownloadDelegate? { get set }

    func getProgress(_ completionHandler: @escaping (Progress?) -> Void)
    func cancel()

    func asNSObject() -> NSObject
}

@objc protocol WebKitDownloadDelegate {

    func download(_ download: WebKitDownload,
                  decideDestinationUsing response: URLResponse?,
                  suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void)

    @objc optional func download(_ download: WebKitDownload,
                                 willPerformHTTPRedirection response: HTTPURLResponse,
                                 newRequest: URLRequest,
                                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)

    @objc optional func download(_ download: WebKitDownload,
                                 didReceiveAuthenticationChallenge challenge: URLAuthenticationChallenge,
                                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)

    @objc optional func downloadDidFinish(_ download: WebKitDownload)

    @objc optional func download(_ download: WebKitDownload, didFailWithError error: Error, resumeData: Data?)
}

protocol WKWebViewDownloadDelegate {
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecomeDownload download: WebKitDownload)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecomeDownload download: WebKitDownload)
}

extension _WKDownload: WebKitDownload {

    private static let downloadDelegateKey = UnsafeRawPointer(bitPattern: "_WKDownloadDelegateKey".hashValue)!
    private static let subscriberRemoverKey = "subscriberRemoverKey"

    var downloadDelegate: WebKitDownloadDelegate? {
        get {
            objc_getAssociatedObject(self, Self.downloadDelegateKey) as? WebKitDownloadDelegate
        }
        set {
            objc_setAssociatedObject(self, Self.downloadDelegateKey, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }

    var downloadRequest: URLRequest? {
        request
    }

    var webView: WKWebView? {
        originatingWebView
    }

    func getProgress(_ completionHandler: @escaping (Progress?) -> Void) {
        guard self.responds(to: #selector(_WKDownload.publishProgress(at:))) else {
            assertionFailure("_WKDownload does not respond to selector \"publishProgressAtURL:\"")
            completionHandler(nil)
            return
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(.uniqueFilename())
        FileManager.default.createFile(atPath: tempURL.path, contents: nil, attributes: nil)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        var subscriber: Any?
        // timeout Subscription after 1s
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            defer { subscriber = nil }
            guard let subscriber = subscriber else { return }
            Progress.removeSubscriber(subscriber)
            completionHandler(nil)
        }

        subscriber = Progress.addSubscriber(forFileURL: tempURL) { [weak timer] progress in
            defer {
                subscriber = nil
                timer?.invalidate()
            }
            guard let subscriber = subscriber else {
                return nil
            }
            // keep Progress subscription active until returned Progress Proxy is alive
            objc_setAssociatedObject(progress,
                                     Self.subscriberRemoverKey,
                                     ProgressSubscriberRemover(subscriber: subscriber),
                                     .OBJC_ASSOCIATION_RETAIN)
            completionHandler(progress)
            return nil
        }

        self.publishProgress(at: tempURL)
    }

    func asNSObject() -> NSObject {
        self
    }

}

private class ProgressSubscriberRemover: NSObject {
    let subscriber: Any

    init(subscriber: Any) {
        self.subscriber = subscriber
    }

    deinit {
        Progress.removeSubscriber(subscriber)
    }
}

@available(macOS 11.3, *)
extension WKDownload: WebKitDownload {

    var downloadDelegate: WebKitDownloadDelegate? {
        get {
            (self.delegate as? WKDownloadDelegateWrapper)?.delegate
        }
        set {
            self.delegate = newValue.map(WKDownloadDelegateWrapper.init(delegate:))
        }
    }

    var downloadRequest: URLRequest? {
        originalRequest
    }

    func getProgress(_ completionHandler: @escaping (Progress?) -> Void) {
        completionHandler(self.progress)
    }

    func cancel() {
        self.cancel { [weak self] resumeData in
            self?.delegate?.download?(self!, didFailWithError: URLError(.cancelled), resumeData: resumeData)
        }
    }

    func asNSObject() -> NSObject {
        self
    }
}

@available(macOS 11.3, *)
final class WKDownloadDelegateWrapper: NSObject, WKDownloadDelegate {
    weak var delegate: WebKitDownloadDelegate?

    private static let delegateWrapperKey = "WKDownloadDelegateWrapperKey"

    init(delegate: WebKitDownloadDelegate) {
        self.delegate = delegate
        super.init()
        objc_setAssociatedObject(delegate, Self.delegateWrapperKey, self, .OBJC_ASSOCIATION_RETAIN)
    }

    func download(_ download: WKDownload,
                  decideDestinationUsing response: URLResponse,
                  suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {

        delegate?.download(download, decideDestinationUsing: response, suggestedFilename: suggestedFilename, completionHandler: completionHandler)
    }

    func downloadDidFinish(_ download: WKDownload) {
        delegate?.downloadDidFinish?(download)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        delegate?.download?(download, didFailWithError: error, resumeData: resumeData)
    }

}
