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

// The methods will be called on an _WKDownload passed as NSObject and
// presented to Swift as a WebKitDownload empty protocol
// Native Swift protocol extension methods will be used as access points
// for the private methods and those will be calling to private _WKDownload methods
// using the Selectors in the ObjCWebKitDownload protocol

// https://github.com/WebKit/WebKit/blob/a6d132292cdb5975a0082a952a270ca1f7b2f7ac/Source/WebKit/UIProcess/API/Cocoa/_WKDownload.mm
@objc private protocol ObjCLegacyWebKitDownload {
    var request: URLRequest? { get }
    var originatingWebView: WKWebView? { get }
    @objc(publishProgressAtURL:)
    func publishProgress(at url: URL)
    func cancel()
}

// https://github.com/WebKit/WebKit/blob/main/Source/WebKit/UIProcess/API/Cocoa/WKDownload.h
@objc private protocol ObjCWebKitDownload: ProgressReporting {
    var originalRequest: URLRequest? { get }

    weak var webView: WKWebView? { get }

    weak var delegate: WebKitDownloadDelegate? { get set }

    func cancel(_ completionHandler: ((/*resumeData:*/ Data?) -> Void)?)
}

// https://github.com/WebKit/WebKit/blob/main/Source/WebKit/UIProcess/API/Cocoa/WKDownloadDelegate.h
@objc protocol WebKitDownloadDelegate {

    @objc(download:decideDestinationUsingResponse:suggestedFilename:completionHandler:)
    func download(_ download: WebKitDownload,
                  decideDestinationUsing response: URLResponse?,
                  suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void)

    @objc(download:willPerformHTTPRedirection:newRequest:decisionHandler:)
    optional func download(_ download: WebKitDownload,
                           willPerformHTTPRedirection response: HTTPURLResponse,
                           newRequest: URLRequest,
                           decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)

    @objc(download:didReceiveAuthenticationChallenge:completionHandler:)
    optional func download(_ download: WebKitDownload,
                           didReceiveAuthenticationChallenge challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)

    @objc
    optional func downloadDidFinish(_ download: WebKitDownload)

    @objc(download:didFailWithError:resumeData:)
    optional func download(_ download: WebKitDownload, didFailWithError error: Error, resumeData: Data?)
}

// Declared as Available for macOS 12 only in WKNavigationDelegate
@objc protocol WKWebViewDownloadDelegate {

    @objc(webView:navigationAction:didBecomeDownload:)
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecomeDownload download: WebKitDownload)
    @objc(webView:navigationResponse:didBecomeDownload:)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecomeDownload download: WebKitDownload)

}

final class WebKitDownload: NSObject {

    @nonobjc
    var request: URLRequest? {
        if self.responds(to: #selector(getter: ObjCWebKitDownload.originalRequest)) {
            return self.perform(#selector(getter: ObjCWebKitDownload.originalRequest))?
                .takeUnretainedValue() as? URLRequest
        } else if self.responds(to: #selector(getter: ObjCLegacyWebKitDownload.request)) {
            return self.perform(#selector(getter: ObjCLegacyWebKitDownload.request))?
                .takeUnretainedValue() as? URLRequest
        }
        assertionFailure("WebKitDownload does not respond to selector \"request\"")
        return nil
    }

    @nonobjc
    var webView: WKWebView? {
        if self.responds(to: #selector(getter: ObjCWebKitDownload.webView)) {
            return self.perform(#selector(getter: ObjCWebKitDownload.webView))?
                .takeUnretainedValue() as? WKWebView
        } else if self.responds(to: #selector(getter: ObjCLegacyWebKitDownload.originatingWebView)) {
            return self.perform(#selector(getter: ObjCLegacyWebKitDownload.originatingWebView))?
                .takeUnretainedValue() as? WKWebView
        }
        assertionFailure("WebKitDownload does not respond to selector \"originatingWebView\"")
        return nil
    }

    private static let subscriberRemoverKey = "subscriberRemoverKey"
    @nonobjc
    func getProgress(_ completionHandler: @escaping (Progress?) -> Void) {
        if let progress = (self as? ProgressReporting)?.progress {
            completionHandler(progress)

        } else if self.responds(to: #selector(ObjCLegacyWebKitDownload.publishProgress(at:))) {
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

            self.perform(#selector(ObjCLegacyWebKitDownload.publishProgress(at:)), with: tempURL)

        } else {
            assertionFailure("WebKitDownload does not respond to selector \"publishProgressAtURL:\"")
        }
    }

    private static let delegateKey = UnsafeRawPointer(bitPattern: "_WKDownloadDelegateKey".hashValue)!
    @nonobjc
    weak var delegate: WebKitDownloadDelegate? {
        get {
            if self.responds(to: #selector(getter: ObjCWebKitDownload.delegate)) {
                return self.perform(#selector(getter: ObjCWebKitDownload.delegate))?
                    .takeUnretainedValue() as? WebKitDownloadDelegate
            }

            return objc_getAssociatedObject(self, Self.delegateKey) as? WebKitDownloadDelegate
        }
        set {
            if self.responds(to: #selector(setter: ObjCWebKitDownload.delegate)) {
                self.perform(#selector(setter: ObjCWebKitDownload.delegate), with: newValue)
                return
            }

            objc_setAssociatedObject(self, Self.delegateKey, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }

    @nonobjc
    func cancel() {
        if self.responds(to: #selector(ObjCWebKitDownload.cancel(_:))) {
            let casted = withUnsafePointer(to: self) {
                $0.withMemoryRebound(to: ObjCWebKitDownload.self, capacity: 1) { $0.pointee }
            }
            casted.cancel { [weak self] resumeData in
                guard let self = self else { return }
                self.delegate?.download?(self, didFailWithError: URLError(.cancelled), resumeData: resumeData as Data?)
            }

        } else if self.responds(to: #selector(ObjCLegacyWebKitDownload.cancel)) {
            self.perform(#selector(ObjCLegacyWebKitDownload.cancel))
        } else {
            assertionFailure("WebKitDownload does not respond to selector \"cancel\"")
        }
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
