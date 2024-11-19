//
//  UnifiedFeedbackSender.swift
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
import PixelKit

enum UnifiedFeedbackSource: String, StringRepresentable {
    case settings, ppro, vpn, pir, itr, unknown
    static var `default` = UnifiedFeedbackSource.unknown

    private static let sourceKey = "source"

    static func userInfo(source: UnifiedFeedbackSource) -> [String: Any] {
        return [sourceKey: source.rawValue]
    }

    init(userInfo: [AnyHashable: Any]?) {
        if let userInfo = userInfo as? [String: Any], let source = userInfo[Self.sourceKey] as? String {
            self = UnifiedFeedbackSource(rawValue: source) ?? .default
        } else {
            self = .default
        }
    }
}

protocol UnifiedFeedbackSender {
    func sendFeatureRequestPixel(description: String, source: UnifiedFeedbackSource) async throws
    func sendGeneralFeedbackPixel(description: String, source: UnifiedFeedbackSource) async throws
    func sendReportIssuePixel<T: UnifiedFeedbackMetadata>(source: UnifiedFeedbackSource, category: String, subcategory: String, description: String, metadata: T?) async throws

    func sendFormShowPixel()
    func sendSubmitScreenShowPixel(source: UnifiedFeedbackSource, reportType: String, category: String, subcategory: String)
    func sendSubmitScreenFAQClickPixel(source: UnifiedFeedbackSource, reportType: String, category: String, subcategory: String)
}

extension UnifiedFeedbackSender {
    func sendStandardPixel(_ pixel: PixelKitEventV2) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PixelKit.fire(pixel, frequency: .standard) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

protocol StringRepresentable: RawRepresentable {
    static var `default`: Self { get }
}

extension StringRepresentable where RawValue == String {
    static func from(_ text: String) -> String {
        (Self(rawValue: text) ?? .default).rawValue
    }
}

struct DefaultFeedbackSender: UnifiedFeedbackSender {
    enum ReportType: String, StringRepresentable {
        case general, reportIssue, requestFeature
        static var `default` = ReportType.general
    }

    enum Category: String, StringRepresentable {
        case subscription, vpn, pir, itr, unknown
        static var `default` = Category.unknown
    }

    enum Subcategory: String, StringRepresentable {
        case otp
        case unableToInstall, failsToConnect, tooSlow, issueWithAppOrWebsite, appCrashesOrFreezes, cantConnectToLocalDevice
        case nothingOnSpecificSite, notMe, scanStuck, removalStuck
        case accessCode, cantContactAdvisor, advisorUnhelpful
        case somethingElse
        static var `default` = Subcategory.somethingElse
    }

    func sendFeatureRequestPixel(description: String, source: UnifiedFeedbackSource) async throws {
        try await sendStandardPixel(GeneralPixel.pproFeedbackFeatureRequest(description: description,
                                                                            source: source.rawValue))
    }

    func sendGeneralFeedbackPixel(description: String, source: UnifiedFeedbackSource) async throws {
        try await sendStandardPixel(GeneralPixel.pproFeedbackGeneralFeedback(description: description,
                                                                             source: source.rawValue))
    }

    func sendReportIssuePixel<T: UnifiedFeedbackMetadata>(source: UnifiedFeedbackSource, category: String, subcategory: String, description: String, metadata: T?) async throws {
        try await sendStandardPixel(GeneralPixel.pproFeedbackReportIssue(source: source.rawValue,
                                                                         category: Category.from(category),
                                                                         subcategory: Subcategory.from(subcategory),
                                                                         description: description,
                                                                         metadata: metadata?.toBase64() ?? ""))
    }

    func sendFormShowPixel() {
        PixelKit.fire(GeneralPixel.pproFeedbackFormShow, frequency: .legacyDailyAndCount)
    }

    func sendSubmitScreenShowPixel(source: UnifiedFeedbackSource, reportType: String, category: String, subcategory: String) {
        PixelKit.fire(GeneralPixel.pproFeedbackSubmitScreenShow(source: source.rawValue,
                                                                reportType: ReportType.from(reportType),
                                                                category: Category.from(category),
                                                                subcategory: Subcategory.from(subcategory)),
                      frequency: .legacyDailyAndCount)
    }

    func sendSubmitScreenFAQClickPixel(source: UnifiedFeedbackSource, reportType: String, category: String, subcategory: String) {
        PixelKit.fire(GeneralPixel.pproFeedbackSubmitScreenFAQClick(source: source.rawValue,
                                                                    reportType: ReportType.from(reportType),
                                                                    category: Category.from(category),
                                                                    subcategory: Subcategory.from(subcategory)),
                      frequency: .legacyDailyAndCount)
    }
}
