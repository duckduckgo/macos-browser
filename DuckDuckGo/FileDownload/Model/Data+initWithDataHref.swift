//
//  Data+initWithDataHref.swift
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
import os.log

extension Data {

    init?(dataHref: String, mimeType: inout String) {
        var scanner = Scanner(string: dataHref)
        guard scanner.scanString("data:") != nil,
              // data:text/plain;charset=utf-8, plaindata
              // data:application/pdf;base64,
              var header = scanner.scanUpToString(",")?.trimmingWhitespaces() ?? .some(""),
              scanner.scanString(",") != nil
        else {
            os_log("HTML5DownloadUserScript: unexpected data format: %s", type: .error, dataHref)
            return nil
        }
        // skip space
        _=scanner.scanString(" ")
        let body = dataHref[scanner.currentIndex...]

        if header.isEmpty {
            header = "text/plain;charset=US-ASCII"
        }
        scanner = Scanner(string: header)
        // text/plain;charset=utf-8,
        // application/pdf;base64,
        // base64,
        let mime = (header == "base64" ? nil : scanner.scanUpToString(";"))
            ?? "text/plain"
        // skip `; `
        _=scanner.scanString(";")
        _=scanner.scanString(" ")

        if scanner.scanString("base64") != nil { // base64
            guard let data = Data(base64Encoded: String(body)) else {
                os_log("HTML5DownloadUserScript: could not decode base64-encoded data: %s", type: .error, dataHref)
                return nil
            }
            self = data
            mimeType = mime

        } else { // plain
            let encoding: String.Encoding
            if scanner.scanString("charset=") != nil,
               let rawEncoding = scanner.scanUpToString(";")
                .map({ $0 as CFString })
                .map(CFStringConvertIANACharSetNameToEncoding)
                .map(CFStringConvertEncodingToNSStringEncoding),
               rawEncoding != UInt32.max {

                encoding = String.Encoding(rawValue: rawEncoding)
            } else {
                encoding = .ascii
            }
            guard let data = body.data(using: encoding) else {
                os_log("HTML5DownloadUserScript: could not decode data: %s", type: .error, dataHref)
                return nil
            }
            self = data
            mimeType = mime
        }
    }

}
