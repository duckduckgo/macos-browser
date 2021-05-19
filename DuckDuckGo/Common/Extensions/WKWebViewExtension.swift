//
//  WKWebViewExtension.swift
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

import WebKit

extension WKWebView {

    func load(_ url: URL) {

        // Occasionally, the web view will try to load a URL but will find itself with no cookies, even if they've been restored.
        // The consumeCookies call is finishing before this line executes, but if you're fast enough it can happen that WKWebView still hasn't
        // processed the cookies that have been set. Pushing the load to the next iteration of the run loops seems to fix this most of the time.
        DispatchQueue.main.async {
            let request = URLRequest(url: url)
            self.load(request)
        }
    }

    struct EvaluateTimeout: Error {}
    func evaluateSynchronously(_ script: String, timeout: TimeInterval? = nil) throws -> Any? {
        var output: (result: Any?, error: Error?)?
        let port = Port()
        RunLoop.current.add(port, forMode: .default)

        let timer = timeout.map { Timer(timeInterval: $0, repeats: false) { _ in
            if output == nil {
                output = (nil, EvaluateTimeout())
            }
        } }
        timer.map { RunLoop.current.add($0, forMode: .default) }

        self.evaluateJavaScript(script) { (result, error) in
            output = (result, error)
            
            let sendPort = Port()
            RunLoop.current.add(sendPort, forMode: .default)
            sendPort.send(before: Date(), components: nil, from: port, reserved: 0)
            RunLoop.current.remove(sendPort, forMode: .default)
        }

        while output == nil {
            RunLoop.current.run(mode: .default, before: .distantFuture)
        }
        timer?.invalidate()
        RunLoop.current.remove(port, forMode: .default)

        if let error = output?.error {
            throw error
        }

        return output?.result
    }

    var mimeType: String? {
        try? self.evaluateSynchronously("document.contentType", timeout: 1.0) as? String
    }

    var contentType: UTType? {
        guard let mimeType = self.mimeType else { return nil }
        return UTType(mimeType: mimeType)
    }

}
