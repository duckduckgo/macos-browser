//
//  MockSchemeTask.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

class MockSchemeTask: NSObject, WKURLSchemeTask {
    var request: URLRequest
    var response: URLResponse?
    var data: Data?
    var didFinishCalled = false
    var error: Error?

    public init(request: URLRequest ) {
        self.request = request
    }

    func didReceive(_ response: URLResponse) {
        self.response = response
    }

    func didReceive(_ data: Data) {
        self.data = data
    }

    func didFinish() {
        didFinishCalled = true
    }

    func didFailWithError(_ error: Error) {
        self.error = error
    }
}
