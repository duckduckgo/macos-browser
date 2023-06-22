//
//  WebOperationRunner.swift
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

protocol WebOperationRunner {

    func scan(_ profileQuery: BrokerProfileQueryData) async throws -> [ExtractedProfile]
    func optOut(_ extractedProfile: ExtractedProfile) async throws
}

// TODO: Remove this
import WebKit

@MainActor
final class TestOperationRunner: WebOperationRunner {

    let webView: WKWebView

    internal init() {
        self.webView = WKWebView(frame: .init(x: 0, y: 0, width: 100, height: 100))
    }

    func scan(_ profileQuery: BrokerProfileQueryData) async throws -> [ExtractedProfile] {
        let extractedProfile = ExtractedProfile(name: "John")
        return [extractedProfile]
    }

    func optOut(_ extractedProfile: ExtractedProfile) async throws {
        print("Fake opt out")
    }

    deinit {
        print("DEINIT")
    }
}
