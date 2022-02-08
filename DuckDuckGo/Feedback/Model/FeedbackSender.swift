//
//  FeedbackSender.swift
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

import Foundation

final class FeedbackSender {

    func sendFeedback() {
        let parameters = [
            "type": "app-feedback",
            "comment": "Testing comment",
            "category": "1199184518165816",
            "osversion": "12.1",
            "appversion": "0.18.4"
        ]

        let url = URL(string: "https://use-tstorey1.duckduckgo.com/feedback.js")!
        APIRequest.request(url: url, method: .post, parameters: parameters) { _, error in
            if let error = error {
                print(error)
            } else {
                print("OK")
            }
        }
    }

}
