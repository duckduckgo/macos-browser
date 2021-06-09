//
//  _WKDownload+WebKitDownload.swift
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

extension _WKDownload: WebKitDownload {

    private static let downloadDelegateKey = UnsafeRawPointer(bitPattern: "_WKDownloadDelegateKey".hashValue)!
    private static let subscriberRemoverKey = "subscriberRemoverKey"

    private class WeakDownloadDelegateRef: NSObject {
        weak var delegate: WebKitDownloadDelegate?
        init(_ delegate: WebKitDownloadDelegate?) {
            self.delegate = delegate
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

    var downloadDelegate: WebKitDownloadDelegate? {
        get {
            (objc_getAssociatedObject(self, Self.downloadDelegateKey) as? WeakDownloadDelegateRef)?.delegate
        }
        set {
            objc_setAssociatedObject(self, Self.downloadDelegateKey, WeakDownloadDelegateRef(newValue), .OBJC_ASSOCIATION_RETAIN)
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
            // keep Progress subscription active until returned Progress Proxy is deallocated
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
