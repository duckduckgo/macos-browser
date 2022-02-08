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
import os.log

final class FeedbackSender {

    static let feedbackURL = URL(string: "https://duckduckgo.com/feedback.js")!

    func sendFeedback(_ feedback: Feedback, appVersion: String, osVersion: String) {
        let parameters = [
            "type": "app-feedback",
            "comment": feedback.comment ?? "",
            "category": feedback.category.asanaId ?? "",
            "osversion": osVersion,
            "appversion": appVersion
        ]

        APIRequest.request(url: Self.feedbackURL, method: .post, parameters: parameters) { _, error in
            if let error = error {
                os_log("FeedbackSender: Failed to submit feedback %s", type: .error, error.localizedDescription)
            }
        }
    }

}
