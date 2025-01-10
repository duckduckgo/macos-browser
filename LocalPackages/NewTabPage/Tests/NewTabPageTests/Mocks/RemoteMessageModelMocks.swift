//
//  RemoteMessageModelMocks.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

import RemoteMessaging

extension RemoteMessageModel {
    static func mockSmall(id: String) -> RemoteMessageModel {
        .init(
            id: id,
            content: .small(titleText: "title", descriptionText: "description"),
            matchingRules: [],
            exclusionRules: [],
            isMetricsEnabled: true
        )
    }

    static func mockMedium(id: String) -> RemoteMessageModel {
        .init(
            id: "sample_message",
            content: .medium(titleText: "title", descriptionText: "description", placeholder: .criticalUpdate),
            matchingRules: [],
            exclusionRules: [],
            isMetricsEnabled: true
        )
    }

    static func mockBigSingleAction(id: String, action: RemoteAction) -> RemoteMessageModel {
        .init(
            id: "sample_message",
            content: .bigSingleAction(
                titleText: "title",
                descriptionText: "description",
                placeholder: .ddgAnnounce,
                primaryActionText: "primary_action",
                primaryAction: action
            ),
            matchingRules: [],
            exclusionRules: [],
            isMetricsEnabled: true
        )
    }

    static func mockBigTwoAction(id: String, primaryAction: RemoteAction, secondaryAction: RemoteAction) -> RemoteMessageModel {
        .init(
            id: "sample_message",
            content: .bigTwoAction(
                titleText: "title",
                descriptionText: "description",
                placeholder: .ddgAnnounce,
                primaryActionText: "primary_action",
                primaryAction: primaryAction,
                secondaryActionText: "secondary_action",
                secondaryAction: secondaryAction
            ),
            matchingRules: [],
            exclusionRules: [],
            isMetricsEnabled: true
        )
    }
}
