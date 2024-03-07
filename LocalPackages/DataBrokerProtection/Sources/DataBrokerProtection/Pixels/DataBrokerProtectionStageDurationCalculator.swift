//
//  DataBrokerProtectionStageDurationCalculator.swift
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
import PixelKit

enum Stage: String {
    case start
    case emailGenerate = "email-generate"
    case captchaParse = "captcha-parse"
    case captchaSend = "captcha-send"
    case captchaSolve = "captcha-solve"
    case submit
    case emailReceive = "email-receive"
    case emailConfirm = "email-confirm"
    case validate
    case other
}

protocol StageDurationCalculator {
    func durationSinceLastStage() -> Double
    func durationSinceStartTime() -> Double
    func fireOptOutStart()
    func fireOptOutEmailGenerate()
    func fireOptOutCaptchaParse()
    func fireOptOutCaptchaSend()
    func fireOptOutCaptchaSolve()
    func fireOptOutSubmit()
    func fireOptOutEmailReceive()
    func fireOptOutEmailConfirm()
    func fireOptOutValidate()
    func fireOptOutSubmitSuccess(tries: Int)
    func fireOptOutFailure(tries: Int)
    func fireScanSuccess(matchesFound: Int)
    func fireScanFailed()
    func fireScanError(error: Error)
    func setStage(_ stage: Stage)
    func setEmailPattern(_ emailPattern: String?)
}

final class DataBrokerProtectionStageDurationCalculator: StageDurationCalculator {
    let handler: EventMapping<DataBrokerProtectionPixels>
    let attemptId: UUID
    let dataBroker: String
    let startTime: Date
    var lastStateTime: Date
    private (set) var stage: Stage = .other
    private (set) var emailPattern: String?

    init(attemptId: UUID = UUID(),
         startTime: Date = Date(),
         dataBroker: String,
         handler: EventMapping<DataBrokerProtectionPixels>) {
        self.attemptId = attemptId
        self.startTime = startTime
        self.lastStateTime = startTime
        self.dataBroker = dataBroker
        self.handler = handler
    }

    /// Returned in milliseconds
    func durationSinceLastStage() -> Double {
        let now = Date()
        let durationSinceLastStage = now.timeIntervalSince(lastStateTime) * 1000
        self.lastStateTime = now

        return durationSinceLastStage.rounded(.towardZero)
    }

    /// Returned in milliseconds
    func durationSinceStartTime() -> Double {
        let now = Date()
        return (now.timeIntervalSince(startTime) * 1000).rounded(.towardZero)
    }

    func fireOptOutStart() {
        setStage(.start)
        handler.fire(.optOutStart(dataBroker: dataBroker, attemptId: attemptId))
    }

    func fireOptOutEmailGenerate() {
        handler.fire(.optOutEmailGenerate(dataBroker: dataBroker, attemptId: attemptId, duration: durationSinceLastStage()))
    }

    func fireOptOutCaptchaParse() {
        handler.fire(.optOutCaptchaParse(dataBroker: dataBroker, attemptId: attemptId, duration: durationSinceLastStage()))
    }

    func fireOptOutCaptchaSend() {
        handler.fire(.optOutCaptchaSend(dataBroker: dataBroker, attemptId: attemptId, duration: durationSinceLastStage()))
    }

    func fireOptOutCaptchaSolve() {
        handler.fire(.optOutCaptchaSolve(dataBroker: dataBroker, attemptId: attemptId, duration: durationSinceLastStage()))
    }

    func fireOptOutSubmit() {
        setStage(.submit)
        handler.fire(.optOutSubmit(dataBroker: dataBroker, attemptId: attemptId, duration: durationSinceLastStage()))
    }

    func fireOptOutEmailReceive() {
        handler.fire(.optOutEmailReceive(dataBroker: dataBroker, attemptId: attemptId, duration: durationSinceLastStage()))
    }

    func fireOptOutEmailConfirm() {
        handler.fire(.optOutEmailConfirm(dataBroker: dataBroker, attemptId: attemptId, duration: durationSinceLastStage()))
    }

    func fireOptOutValidate() {
        setStage(.validate)
        handler.fire(.optOutValidate(dataBroker: dataBroker, attemptId: attemptId, duration: durationSinceLastStage()))
    }

    func fireOptOutSubmitSuccess(tries: Int) {
        handler.fire(.optOutSubmitSuccess(dataBroker: dataBroker,
                                          attemptId: attemptId,
                                          duration: durationSinceStartTime(),
                                          tries: tries,
                                          emailPattern: emailPattern))
    }

    func fireOptOutFailure(tries: Int) {
        handler.fire(.optOutFailure(dataBroker: dataBroker,
                                    attemptId: attemptId,
                                    duration: durationSinceStartTime(),
                                    stage: stage.rawValue,
                                    tries: tries,
                                    emailPattern: emailPattern))
    }

    func fireScanSuccess(matchesFound: Int) {
        handler.fire(.scanSuccess(dataBroker: dataBroker, matchesFound: matchesFound, duration: durationSinceStartTime(), tries: 1))
    }

    func fireScanFailed() {
        handler.fire(.scanFailed(dataBroker: dataBroker, duration: durationSinceStartTime(), tries: 1))
    }

    func fireScanError(error: Error) {
        var errorCategory: ErrorCategory = .unclassified

        if let dataBrokerProtectionError = error as? DataBrokerProtectionError {
            switch dataBrokerProtectionError {
            case .httpError(let httpCode):
                if httpCode < 500 {
                    errorCategory = .clientError(httpCode: httpCode)
                } else {
                    errorCategory = .serverError(httpCode: httpCode)
                }
            default:
                errorCategory = .validationError
            }
        } else {
            if let nsError = error as NSError? {
                if nsError.domain == NSURLErrorDomain {
                    errorCategory = .networkError
                }
            }
        }

        handler.fire(
            .scanError(
                dataBroker: dataBroker,
                duration: durationSinceStartTime(),
                category: errorCategory.toString,
                details: error.localizedDescription
            )
        )
    }

    // Helper methods to set the stage that is about to run. This help us
    // identifying the stage so we can know which one was the one that failed.

    func setStage(_ stage: Stage) {
        self.stage = stage
    }

    func setEmailPattern(_ emailPattern: String?) {
        self.emailPattern = emailPattern
    }
}
