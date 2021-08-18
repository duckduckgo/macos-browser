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

private let downloadDelegateKey = UnsafeRawPointer(bitPattern: "_WKDownloadDelegateKey".hashValue)!

#if swift(>=5.4)
// if building on Xcode 12.5 (macOS >= 11.3) make WKDownload conform to WebKitDownload and ObjCWKDownloadProtocol
@available(macOS 11.3, *)
extension WKDownload: WebKitDownload, ObjCWKDownloadProtocol {}
let initWKDownload: Void = ()
#else
// otherwise register a not-yet known in compile time WKDownload to conform to ObjCWKDownloadProtocol
// to be able to call WKDownload's methods natively on newer systems without calling performSelector:
let initWKDownload: Void = {
    guard #available(OSX 11.3, *),
          let WKDownload: AnyClass = NSClassFromString("WKDownload")
    else { return }
    class_addProtocol(WKDownload, ObjCWKDownloadProtocol.self)
}()
#endif

// Implemented as a Swift Protocol extension to avoid missing WKDownload Symbol requirement in macOS 10.13 causing build to crash
extension WebKitDownload {

    var downloadDelegate: WebKitDownloadDelegate? {
        get {
            if #available(OSX 11.3, *),
               let download = self as? ObjCWKDownloadProtocol {
                let wrapper = download.delegate as? WKDownloadDelegateWrapper
                return wrapper?.delegate

            } else {
                return (objc_getAssociatedObject(self, downloadDelegateKey) as? WeakDownloadDelegateRef)?.delegate
            }
        }
        set {
            _=initWKDownload
            if #available(OSX 11.3, *),
               let download = self as? ObjCWKDownloadProtocol {
                let delegateWrapper = newValue.map(WKDownloadDelegateWrapper.init(delegate:))
                download.delegate = delegateWrapper
            } else {
                objc_setAssociatedObject(self, downloadDelegateKey, WeakDownloadDelegateRef(newValue), .OBJC_ASSOCIATION_RETAIN)
            }
        }
    }

    func getProgress(_ completionHandler: @escaping (Progress?) -> Void) {
        if let progressReporting = self as? ProgressReporting {
            completionHandler(progressReporting.progress)
        } else if let download = self as? _WKDownload {
            download.getProgress(completionHandler)
        } else {
            assertionFailure("Unexpected Download class: \(self)")
            completionHandler(nil)
        }
    }

    func cancel() {
        if #available(OSX 11.3, *),
           let download = self as? ObjCWKDownloadProtocol {
            download.cancel { [weak self] resumeData in
                // WKDownload.cancel(_:) does not produce delegate method call whereas _WKDownload.cancel calls _downloadDidCancel(:_)
                // calling delegate method here to make it consistent
                self?.downloadDelegate?.download?(self!, didFailWithError: URLError(.cancelled), resumeData: resumeData)
            }
        } else if let download = self as? _WKDownload {
            return download.cancel()
        }
    }

    func asNSObject() -> NSObject {
        self as! NSObject // swiftlint:disable:this force_cast
    }

}

// Used for forwarding WKDownloadDelegate methods with WKDownload sender to WebKitDownloadDelegate methods
// with universal sender protocol WebKitDownload representing both WKDownload and Legacy _WKDownload classes
@available(macOS 11.3, *)
final private class WKDownloadDelegateWrapper: NSObject, WKDownloadDelegate {
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

    func download(_ download: WKDownload,
                  willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest,
                  decisionHandler: @escaping (WKDownload.RedirectPolicy) -> Void) {
        delegate?.download?(download, willPerformHTTPRedirection: response, newRequest: request) {
            switch $0 {
            case .cancel:
                decisionHandler(.cancel)
            case .allow:
                decisionHandler(.allow)
            @unknown default:
                decisionHandler(.allow)
            }
        } ?? {
            decisionHandler(.allow)
        }()
    }

    func download(_ download: WKDownload,
                  didReceive challenge: URLAuthenticationChallenge,
                  completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        delegate?.download?(download, didReceive: challenge, completionHandler: completionHandler) ?? {
            completionHandler(.performDefaultHandling, nil)
        }()
    }

    func downloadDidFinish(_ download: WKDownload) {
        delegate?.downloadDidFinish?(download)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        delegate?.download?(download, didFailWithError: error, resumeData: resumeData)
    }
}

final private class WeakDownloadDelegateRef: NSObject {
    weak var delegate: WebKitDownloadDelegate?
    init(_ delegate: WebKitDownloadDelegate?) {
        self.delegate = delegate
    }
}
