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

@objc enum WebKitDownloadRedirectPolicy: Int {
    case cancel
    case allow
}

@objc protocol WebKitDownloadDelegate: AnyObject {

    func download(_ download: WebKitDownload,
                  decideDestinationUsing response: URLResponse?,
                  suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void)

    func download(_ download: WebKitDownload,
                  willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest,
                  decisionHandler: @escaping (WebKitDownloadRedirectPolicy) -> Void)

    func download(_ download: WebKitDownload,
                  didReceive challenge: URLAuthenticationChallenge,
                  completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)

    func downloadDidFinish(_ download: WebKitDownload)

    func download(_ download: WebKitDownload, didFailWithError error: Error, resumeData: Data?)

    func download(_ download: WebKitDownload, didReceiveData length: UInt64)

}
