//
//  TwoFactorCodeDetector.swift
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
import AVFoundation
import SwiftOTP

final class TwoFactorCodeDetector {

    static func detectTwoFactorCode(in webView: WKWebView, completion: @escaping (URL?) -> Void) {
        webView.takeSnapshot(with: nil) { image, error in
            let features = features(for: image)
            let qrCodeFeature = features?.first as? CIQRCodeFeature

            if let messageURLString = qrCodeFeature?.messageString, let messageURL = URL(string: messageURLString) {
                completion(messageURL)

                let components = URLComponents(url: messageURL, resolvingAgainstBaseURL: false)
                let secretQueryItem = components?.queryItems?.first { $0.name == "secret" }
                let secret = secretQueryItem!.value!
                let base32Decoded = base32DecodeToData(secret)!

                let totp = TOTP(secret: base32Decoded, digits: 6, timeInterval: 30, algorithm: .sha1)!
                let otpString = totp.generate(time: Date())

                print(otpString!)
            } else {
                completion(nil)
            }
        }
    }

    static func secret(for image: NSImage?) -> URL? {
        guard let features = features(for: image), let qrCodeFeature = features.first as? CIQRCodeFeature else {
            return nil
        }

        if let messageURLString = qrCodeFeature.messageString, let messageURL = URL(string: messageURLString) {
            return messageURL
        }

        return nil
    }

    static func features(for image: NSImage?) -> [CIFeature]? {
        guard let imageData = image?.tiffRepresentation, let bitmap = NSBitmapImageRep(data: imageData) else {
            return nil
        }

        let image = CIImage(bitmapImageRep: bitmap)!

        var options: [String: Any] = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        let context = CIContext()

        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: context, options: options)

        if image.properties.keys.contains((kCGImagePropertyOrientation as String)) {
            options = [CIDetectorImageOrientation: image.properties[(kCGImagePropertyOrientation as String)] ?? 1]
        } else {
            options = [CIDetectorImageOrientation: 1]
        }

        return detector?.features(in: image, options: options)
    }

    static func calculateSixDigitCode(secret: String?, date: Date = Date()) -> String {
        guard let secret = secret, let secretURL = URL(string: secret) else {
            return ""
        }

        let components = URLComponents(url: secretURL, resolvingAgainstBaseURL: false)
        let secretQueryItem = components?.queryItems?.first { $0.name == "secret" }
        guard let secretValue = secretQueryItem?.value else {
            return ""
        }

        let base32Decoded = base32DecodeToData(secretValue)!

        let totp = TOTP(secret: base32Decoded, digits: 6, timeInterval: 30, algorithm: .sha1)!
        return totp.generate(time: date)!
    }

}
