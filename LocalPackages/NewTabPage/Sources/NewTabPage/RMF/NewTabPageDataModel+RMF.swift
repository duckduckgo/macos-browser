//
//  NewTabPageDataModel+RMF.swift
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
import RemoteMessaging

extension NewTabPageDataModel {

    struct RemoteMessageParams: Codable {
        let id: String
    }

    struct RMFData: Encodable {
        let content: RMFMessage?
    }

    enum RMFMessage: Encodable, Equatable {
        case small(SmallMessage), medium(MediumMessage), bigSingleAction(BigSingleActionMessage), bigTwoAction(BigTwoActionMessage)

        func encode(to encoder: any Encoder) throws {
            try message.encode(to: encoder)
        }

        var message: Encodable {
            switch self {
            case .small(let message):
                return message
            case .medium(let message):
                return message
            case .bigSingleAction(let message):
                return message
            case .bigTwoAction(let message):
                return message
            }
        }

        init?(_ remoteMessageModel: RemoteMessageModel) {
            guard let modelType = remoteMessageModel.content else {
                return nil
            }

            switch modelType {
            case let .small(titleText, descriptionText):
                self = .small(.init(id: remoteMessageModel.id, titleText: titleText, descriptionText: descriptionText))

            case let .medium(titleText, descriptionText, placeholder):
                self = .medium(.init(id: remoteMessageModel.id, titleText: titleText, descriptionText: descriptionText, icon: .init(placeholder)))

            case let .bigSingleAction(titleText, descriptionText, placeholder, primaryActionText, _):
                self = .bigSingleAction(.init(id: remoteMessageModel.id, titleText: titleText, descriptionText: descriptionText, icon: .init(placeholder), primaryActionText: primaryActionText))

            case let .bigTwoAction(titleText, descriptionText, placeholder, primaryActionText, _, secondaryActionText, _):
                self = .bigTwoAction(.init(id: remoteMessageModel.id, titleText: titleText, descriptionText: descriptionText, icon: .init(placeholder), primaryActionText: primaryActionText, secondaryActionText: secondaryActionText))

            default:
                return nil
            }
        }
    }

    struct SmallMessage: Encodable, Equatable {
        let messageType = "small"

        let id: String
        let titleText: String
        let descriptionText: String
    }

    struct MediumMessage: Encodable, Equatable {
        let messageType = "medium"

        let id: String
        let titleText: String
        let descriptionText: String
        let icon: RMFIcon
    }

    struct BigSingleActionMessage: Encodable, Equatable {
        let messageType = "big_single_action"

        let id: String
        let titleText: String
        let descriptionText: String
        let icon: RMFIcon
        let primaryActionText: String
    }

    struct BigTwoActionMessage: Encodable, Equatable {
        let messageType = "big_two_action"

        let id: String
        let titleText: String
        let descriptionText: String
        let icon: RMFIcon
        let primaryActionText: String
        let secondaryActionText: String
    }

    enum RMFIcon: String, Encodable {
        case announce = "Announce"
        case ddgAnnounce = "DDGAnnounce"
        case criticalUpdate = "CriticalUpdate"
        case appUpdate = "AppUpdate"
        case privacyPro = "PrivacyPro"

        init(_ placeholder: RemotePlaceholder) {
            switch placeholder {
            case .announce:
                self = .announce
            case .ddgAnnounce:
                self = .ddgAnnounce
            case .criticalUpdate:
                self = .criticalUpdate
            case .appUpdate:
                self = .appUpdate
            case .privacyShield:
                self = .privacyPro
            default:
                self = .ddgAnnounce
            }
        }
    }
}
