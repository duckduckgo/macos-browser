//
//  FeedbackCategoryProviding.swift
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

protocol FeedbackCategoryProviding: Hashable, CaseIterable, Identifiable, RawRepresentable {
    static var prompt: Self { get }
    var displayName: String { get }
}

protocol FeedbackFAQProviding {
    var url: URL? { get }
}

extension FeedbackCategoryProviding where RawValue == String {
    var id: String {
        rawValue
    }
}

enum UnifiedFeedbackReportType: String, FeedbackCategoryProviding {
    case selectReportType
    case reportIssue
    case requestFeature
    case general

    static var prompt = UnifiedFeedbackReportType.selectReportType

    var displayName: String {
        switch self {
        case .selectReportType: return UserText.browserFeedbackSelectCategory
        case .reportIssue: return UserText.browserFeedbackReportProblem
        case .requestFeature: return UserText.browserFeedbackRequestFeature
        case .general: return UserText.browserFeedbackGeneralFeedback
        }
    }
}

enum UnifiedFeedbackCategory: String, FeedbackCategoryProviding {
    case selectFeature
    case subscription
    case vpn
    case pir
    case itr

    static var prompt = UnifiedFeedbackCategory.selectFeature

    var displayName: String {
        switch self {
        case .selectFeature: return UserText.generalFeedbackFormCategorySelect
        case .subscription: return UserText.generalFeedbackFormCategoryPPro
        case .vpn: return UserText.generalFeedbackFormCategoryVPN
        case .pir: return UserText.generalFeedbackFormCategoryPIR
        case .itr: return UserText.generalFeedbackFormCategoryITR
        }
    }
}

enum PrivacyProFeedbackSubcategory: String, FeedbackCategoryProviding, FeedbackFAQProviding {
    case selectSubcategory
    case otp
    case somethingElse

    static var prompt = PrivacyProFeedbackSubcategory.selectSubcategory

    var displayName: String {
        switch self {
        case .selectSubcategory: return UserText.pproFeedbackFormCategorySelect
        case .otp: return UserText.pproFeedbackFormCategoryOTP
        case .somethingElse: return UserText.pproFeedbackFormCategoryOther
        }
    }

    var url: URL? {
        switch self {
        case .selectSubcategory: return nil
        case .otp: return URL(string: "https://duckduckgo.com/duckduckgo-help-pages/privacy-pro/payments/")!
        case .somethingElse: return URL(string: "https://duckduckgo.com/duckduckgo-help-pages/privacy-pro/payments/")!
        }
    }
}

enum VPNFeedbackSubcategory: String, FeedbackCategoryProviding, FeedbackFAQProviding {
    case selectSubcategory
    case unableToInstall
    case failsToConnect
    case tooSlow
    case issueWithAppOrWebsite
    case appCrashesOrFreezes
    case cantConnectToLocalDevice
    case somethingElse

    static var prompt = VPNFeedbackSubcategory.selectSubcategory

    var displayName: String {
        switch self {
        case .selectSubcategory: return UserText.vpnFeedbackFormCategorySelect
        case .unableToInstall: return UserText.vpnFeedbackFormCategoryUnableToInstall
        case .failsToConnect: return UserText.vpnFeedbackFormCategoryFailsToConnect
        case .tooSlow: return UserText.vpnFeedbackFormCategoryTooSlow
        case .issueWithAppOrWebsite: return UserText.vpnFeedbackFormCategoryIssuesWithApps
        case .appCrashesOrFreezes: return UserText.vpnFeedbackFormCategoryBrowserCrashOrFreeze
        case .cantConnectToLocalDevice: return UserText.vpnFeedbackFormCategoryLocalDeviceConnectivity
        case .somethingElse: return UserText.vpnFeedbackFormCategoryOther
        }
    }

    var url: URL? {
        switch self {
        case .selectSubcategory: return nil
        case .unableToInstall: return URL(string: "https://duckduckgo.com/duckduckgo-help-pages/privacy-pro/vpn/troubleshooting/")!
        case .failsToConnect: return URL(string: "https://duckduckgo.com/duckduckgo-help-pages/privacy-pro/vpn/troubleshooting/")!
        case .tooSlow: return URL(string: "https://duckduckgo.com/duckduckgo-help-pages/privacy-pro/vpn/troubleshooting/")!
        case .issueWithAppOrWebsite: return URL(string: "https://duckduckgo.com/duckduckgo-help-pages/privacy-pro/vpn/troubleshooting/")!
        case .appCrashesOrFreezes: return URL(string: "https://duckduckgo.com/duckduckgo-help-pages/privacy-pro/vpn/troubleshooting/")!
        case .cantConnectToLocalDevice: return URL(string: "https://duckduckgo.com/duckduckgo-help-pages/privacy-pro/vpn/troubleshooting/")!
        case .somethingElse: return URL(string: "https://duckduckgo.com/duckduckgo-help-pages/privacy-pro/vpn/")!
        }
    }
}

enum PIRFeedbackSubcategory: String, FeedbackCategoryProviding, FeedbackFAQProviding {
    case selectSubcategory
    case nothingOnSpecificSite
    case notMe
    case scanStuck
    case removalStuck
    case somethingElse

    static var prompt = PIRFeedbackSubcategory.selectSubcategory

    var displayName: String {
        switch self {
        case .selectSubcategory: return UserText.pirFeedbackFormCategorySelect
        case .nothingOnSpecificSite: return UserText.pirFeedbackFormCategoryNothingOnSpecificSite
        case .notMe: return UserText.pirFeedbackFormCategoryNotMe
        case .scanStuck: return UserText.pirFeedbackFormCategoryScanStuck
        case .removalStuck: return UserText.pirFeedbackFormCategoryRemovalStuck
        case .somethingElse: return UserText.pirFeedbackFormCategoryOther
        }
    }

    var url: URL? {
        switch self {
        case .selectSubcategory: return nil
        case .nothingOnSpecificSite: return URL(string: "https://duckduckgo.com/duckduckgo-help-pages/privacy-pro/personal-information-removal/removal-process/")!
        case .notMe: return URL(string: "https://duckduckgo.com/duckduckgo-help-pages/privacy-pro/personal-information-removal/removal-process/")!
        case .scanStuck: return URL(string: "https://duckduckgo.com/duckduckgo-help-pages/privacy-pro/personal-information-removal/removal-process/")!
        case .removalStuck: return URL(string: "https://duckduckgo.com/duckduckgo-help-pages/privacy-pro/personal-information-removal/removal-process/")!
        case .somethingElse: return URL(string: "https://duckduckgo.com/duckduckgo-help-pages/privacy-pro/personal-information-removal/")!
        }
    }
}

enum ITRFeedbackSubcategory: String, FeedbackCategoryProviding, FeedbackFAQProviding {
    case selectSubcategory
    case accessCode
    case cantContactAdvisor
    case advisorUnhelpful
    case somethingElse

    static var prompt = ITRFeedbackSubcategory.selectSubcategory

    var displayName: String {
        switch self {
        case .selectSubcategory: return UserText.itrFeedbackFormCategorySelect
        case .accessCode: return UserText.itrFeedbackFormCategoryAccessCode
        case .cantContactAdvisor: return UserText.itrFeedbackFormCategoryCantContactAdvisor
        case .advisorUnhelpful: return UserText.itrFeedbackFormCategoryUnhelpful
        case .somethingElse: return UserText.itrFeedbackFormCategorySomethingElse
        }
    }

    var url: URL? {
        switch self {
        case .selectSubcategory: return nil
        case .accessCode: return URL(string: "https://duckduckgo.com/duckduckgo-help-pages/privacy-pro/identity-theft-restoration/")!
        case .cantContactAdvisor: return URL(string: "https://duckduckgo.com/duckduckgo-help-pages/privacy-pro/identity-theft-restoration/iris/")!
        case .advisorUnhelpful: return URL(string: "https://duckduckgo.com/duckduckgo-help-pages/privacy-pro/identity-theft-restoration/")!
        case .somethingElse: return URL(string: "https://duckduckgo.com/duckduckgo-help-pages/privacy-pro/identity-theft-restoration/")!
        }
    }
}
