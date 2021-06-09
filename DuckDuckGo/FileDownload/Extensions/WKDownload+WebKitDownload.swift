//
//  WKDownload+WebKitDownload.swift
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

@available(macOS 11.3, *)
extension WKDownload: WebKitDownload {

    // Used for forwarding WKDownloadDelegate methods with WKDownload sender to WebKitDownloadDelegate methods
    // with universal sender protocol WebKitDownload representing both WKDownload and Legacy _WKDownload classes
    final class WKDownloadDelegateWrapper: NSObject, WKDownloadDelegate {
        weak var delegate: WebKitDownloadDelegate?

        private static let delegateWrapperKey = "WKDownloadDelegateWrapperKey"

        init(delegate: WebKitDownloadDelegate) {
            self.delegate = delegate
            super.init()
            // keep the Wrapper alive while actual WebKitDownloadDelegate is alive
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
            // WKDownload.cancel does not produce delegate method call whereas _WKDownload.cancel calls _downloadDidCancel(:_)
            // calling delegate method here to make it consistent
            self?.delegate?.download?(self!, didFailWithError: URLError(.cancelled), resumeData: resumeData)
        }
    }

    func asNSObject() -> NSObject {
        self
    }

}
