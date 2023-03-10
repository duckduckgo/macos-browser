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
import Networking

final class FeedbackSender {

    static let feedbackURL = URL(string: "https://duckduckgo.com/feedback.js")!

    func sendFeedback(_ feedback: Feedback) {
#if APPSTORE
        let appVersion = "\(feedback.appVersion) AppStore"
#else
        let appVersion = feedback.appVersion
#endif
        let parameters = [
            "type": "app-feedback",
            "comment": feedback.comment,
            "category": feedback.category.asanaId,
            "osversion": feedback.osVersion,
            "appversion": appVersion
        ]

        let configuration = APIRequest.Configuration(url: Self.feedbackURL, method: .post, queryParameters: parameters)
        let request = APIRequest(configuration: configuration, urlSession: URLSession.session())
        request.fetch { _, error in
            if let error = error {
                os_log("FeedbackSender: Failed to submit feedback %s", type: .error, error.localizedDescription)
                Pixel.fire(.debug(event: .feedbackReportingFailed, error: error))
            }
        }
    }

}

fileprivate extension Feedback.Category {

    var asanaId: String {
        switch self {
        case .bug: return "1199184518165816"
        case .featureRequest: return "1199184518165815"
        case .other: return "1200574389728916"
        }
    }

}
