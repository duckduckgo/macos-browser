//
//  CrashReportSender.swift
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

#if OUT_OF_APPSTORE

final class CrashReportSender {

    static let reportServiceUrl = URL(string: "https://duckduckgo.com/crash.js")!

    func send(_ crashReport: CrashReport) {
        guard let contentData = crashReport.contentData else {
            assertionFailure("CrashReportSender: Can't get the content of the crash report")
            return
        }
        var request = URLRequest(url: Self.reportServiceUrl)
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.setValue("ddg_mac", forHTTPHeaderField: "User-Agent")
        request.httpMethod = "POST"
        request.httpBody = contentData
        request.httpShouldHandleCookies = true
        
        // Visit the report service URL in a webpage and monitor the request, pull out the Duo cookie and paste it here in order for crashes to send.
        request.setValue("", forHTTPHeaderField: "Cookie")

        print("SENDING CRASH: \(request)")
        
        URLSession.shared.dataTask(with: request) { (_, _, error) in
            if error != nil {
                assertionFailure("CrashReportSender: Failed to send the crash reprot")
            }
        }.resume()
    }

}

#endif
