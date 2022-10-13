//
//  YoutubeOverlayUserScript+Encryption.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

// This file is mostly a copy-paste of AutofillUserScript+Encryption.swift from BSK (internal API).
// Autofill solution will be refactored into a universal API and applied to Youtube Overlay script.

import Foundation
import CryptoKit
import WebKit

protocol YoutubeEncrypter {
    func encryptReply(_ reply: String, key: [UInt8], iv: [UInt8]) throws -> (ciphertext: Data, tag: Data)
}

struct AESGCMYoutubeOverlayEncrypter: YoutubeEncrypter {

    enum Error: Swift.Error {
        case encodingReply
    }

    public func encryptReply(_ reply: String, key: [UInt8], iv: [UInt8]) throws -> (ciphertext: Data, tag: Data) {
        guard let replyData = reply.data(using: .utf8) else {
            throw Error.encodingReply
        }
        let sealed = try AES.GCM.seal(replyData, using: .init(data: key), nonce: .init(data: iv))
        return (ciphertext: sealed.ciphertext, tag: sealed.tag)
    }

}

protocol YoutubeHostProvider {

    func hostForMessage(_ message: YoutubeMessage) -> String

}

struct SecurityOriginHostProvider: YoutubeHostProvider {

    public func hostForMessage(_ message: YoutubeMessage) -> String {
        return message.messageHost
    }

}

protocol YoutubeMessage {
    var messageName: String { get }
    var messageBody: Any { get }
    var messageHost: String { get }
    var isMainFrame: Bool { get }
    var messageWebView: WKWebView? { get }
}

extension WKScriptMessage: YoutubeMessage {
    var messageName: String {
        return name
    }

    var messageBody: Any {
        return body
    }

    var messageHost: String {
        return frameInfo.securityOrigin.host
    }

    var isMainFrame: Bool {
        return frameInfo.isMainFrame
    }

    var messageWebView: WKWebView? {
        return webView
    }
}
