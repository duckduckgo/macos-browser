//
//  VPNFeedbackSender.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import PixelKit

protocol VPNFeedbackSender {
    func send(metadata: VPNMetadata, category: VPNFeedbackCategory, userText: String) async throws
}

struct DefaultVPNFeedbackSender: VPNFeedbackSender {

    func send(metadata: VPNMetadata, category: VPNFeedbackCategory, userText: String) async throws {
        let urlAllowed: CharacterSet = .alphanumerics.union(.init(charactersIn: "-._~"))
        let encodedUserText = userText.addingPercentEncoding(withAllowedCharacters: urlAllowed) ?? userText
        let pixelEvent = GeneralPixel.vpnBreakageReport(category: category.rawValue, description: encodedUserText, metadata: metadata.toBase64())

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PixelKit.fire(pixelEvent) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

}
