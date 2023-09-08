//
//  DataBrokerProtectionPixels.swift
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
import Common
import BrowserServicesKit

struct DataBrokerProtectionStageDurationCalculator {

    let handler: EventMapping<DataBrokerProtectionPixels>

    private let attemptId: UUID
    private let dataBroker: String
    private var lastStateTime: DispatchTime

    init(attemptId: UUID = UUID(),
         lastStateTime: DispatchTime = .now(),
         dataBroker: String,
         handler: EventMapping<DataBrokerProtectionPixels>) {
        self.attemptId = attemptId
        self.lastStateTime = lastStateTime
        self.dataBroker = dataBroker
        self.handler = handler
    }

    /// Returned in milliseconds
    mutating func durationSinceLastStage() -> Double {
        let now = DispatchTime.now()
        let executionTime = now.uptimeNanoseconds - lastStateTime.uptimeNanoseconds
        self.lastStateTime = now
        return Double(executionTime) / 1_000_000
    }

    func fireOptOutStart() {
        handler.fire(.optOutStart(dataBroker: dataBroker, attemptId: attemptId))
    }
}

public enum DataBrokerProtectionPixels {
    struct Consts {
        static let dataBrokerParamKey = "data_broker"
        static let appVersionParamKey = "app_version"
        static let attemptIdParamKey = "attempt_id"
        static let durationParamKey = "duration"
    }

    case error(error: DataBrokerProtectionError, dataBroker: String)

    // Stage Pixels
    case optOutStart(dataBroker: String, attemptId: UUID)
    case optOutEmailGenerate(dataBroker: String, attemptId: UUID, duration: UInt64)
    case optOutCaptchaParse(dataBroker: String, attemptId: UUID, duration: UInt64)
    case optOutCaptchaSend(dataBroker: String, attemptId: UUID, duration: UInt64)
    case optOutCaptchaSolve(dataBroker: String, attemptId: UUID, duration: UInt64)
    case optOutSubmit(dataBroker: String, attemptId: UUID, duration: UInt64)
    case optOutEmailReceive(dataBroker: String, attemptId: UUID, duration: UInt64)
    case optOutEmailConfirm(dataBroker: String, attemptId: UUID, duration: UInt64)
    case optOutValidate(dataBroker: String, attemptId: UUID, duration: UInt64)
    case optOutFinish(dataBroker: String, attemptId: UUID, duration: UInt64)

    // Process Pixels
    case optOutSuccess(dataBroker: String, attemptId: UUID, duration: UInt64)
    case optOutFailure(dataBroker: String, attemptId: UUID, duration: UInt64)
}

public extension DataBrokerProtectionPixels {

    var params: [String: String] {
        var pixelParams = internalParams

        if let appVersion = AppVersionProvider().appVersion() {
            pixelParams[Consts.appVersionParamKey] = appVersion
        }

        return pixelParams
    }

    private var internalParams: [String: String] {
        switch self {
        case .error(let error, let dataBroker):
            if case let .actionFailed(actionID, message) = error {
                return ["dataBroker": dataBroker,
                        "name": error.name,
                        "actionID": actionID,
                        "message": message]
            } else {
                return ["dataBroker": dataBroker, "name": error.name]
            }
        case .optOutStart(let dataBroker, let attemptId):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString]
        case .optOutEmailGenerate(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutCaptchaParse(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutCaptchaSend(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutCaptchaSolve(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutSubmit(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutEmailReceive(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutEmailConfirm(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutValidate(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutFinish(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutSuccess(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutFailure(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        }
    }
}
