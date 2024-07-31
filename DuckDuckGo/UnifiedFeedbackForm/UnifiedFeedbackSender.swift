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

protocol UnifiedFeedbackSender {
    func sendFeatureRequestPixel(description: String, source: String) async throws
    func sendGeneralFeedbackPixel(description: String, source: String) async throws
    func sendReportIssuePixel<T: UnifiedFeedbackMetadata>(source: String, category: String, subcategory: String, description: String, metadata: T?) async throws

    func sendGeneralScreenShowPixel() async
    func sendActionsScreenShowPixel(source: String) async
    func sendCategoryScreenShowPixel(source: String, reportType: String) async
    func sendSubcategoryScreenShowPixel(source: String, reportType: String, category: String) async
    func sendSubmitScreenShowPixel(source: String, reportType: String, category: String, subcategory: String) async
}

extension UnifiedFeedbackSender {
    static func encode(_ text: String) -> String {
        let urlAllowed: CharacterSet = .alphanumerics.union(.init(charactersIn: "-._~"))
        return text.addingPercentEncoding(withAllowedCharacters: urlAllowed) ?? text
    }

    func sendPixel(_ pixel: PixelKitEventV2, frequency: PixelKit.Frequency = .standard) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var count = 0
            PixelKit.fire(pixel, frequency: frequency) { _, error in
                count += 1
                if let error {
                    continuation.resume(throwing: error)
                } else if frequency != .dailyAndCount || count == 2 {
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
    enum Source: String, StringRepresentable {
        case settings, ppro, vpn, pir, itr, unknown
        static var `default` = Source.unknown
    }

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

    func sendFeatureRequestPixel(description: String, source: String) async throws {
        try await sendPixel(GeneralPixel.pproFeedbackFeatureRequest(description: Self.encode(description),
                                                                    source: Source.from(source)))
    }

    func sendGeneralFeedbackPixel(description: String, source: String) async throws {
        try await sendPixel(GeneralPixel.pproFeedbackGeneralFeedback(description: Self.encode(description),
                                                                     source: Source.from(source)))
    }

    func sendReportIssuePixel<T: UnifiedFeedbackMetadata>(source: String, category: String, subcategory: String, description: String, metadata: T?) async throws {
        try await sendPixel(GeneralPixel.pproFeedbackReportIssue(source: Source.from(source),
                                                                 category: Category.from(category),
                                                                 subcategory: Subcategory.from(subcategory),
                                                                 description: Self.encode(description),
                                                                 metadata: metadata?.toBase64() ?? ""))
    }

    func sendGeneralScreenShowPixel() async {
        try? await sendPixel(GeneralPixel.pproFeedbackGeneralScreenShow,
                             frequency: .dailyAndCount)
    }

    func sendActionsScreenShowPixel(source: String) async {
        try? await sendPixel(GeneralPixel.pproFeedbackActionsScreenShow(source: source),
                             frequency: .dailyAndCount)
    }

    func sendCategoryScreenShowPixel(source: String, reportType: String) async {
        try? await sendPixel(GeneralPixel.pproFeedbackCategoryScreenShow(source: source,
                                                                         reportType: ReportType.from(reportType)),
                             frequency: .dailyAndCount)
    }

    func sendSubcategoryScreenShowPixel(source: String, reportType: String, category: String) async {
        try? await sendPixel(GeneralPixel.pproFeedbackSubcategoryScreenShow(source: source,
                                                                            reportType: ReportType.from(reportType),
                                                                            category: Category.from(category)),
                             frequency: .dailyAndCount)
    }

    func sendSubmitScreenShowPixel(source: String, reportType: String, category: String, subcategory: String) async {
        try? await sendPixel(GeneralPixel.pproFeedbackSubmitScreenShow(source: source,
                                                                       reportType: ReportType.from(reportType),
                                                                       category: Category.from(category),
                                                                       subcategory: Subcategory.from(subcategory)),
                             frequency: .dailyAndCount)
    }
}
