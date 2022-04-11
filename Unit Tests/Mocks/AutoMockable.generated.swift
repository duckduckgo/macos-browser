// Generated using Sourcery 1.7.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
//
// AutoMockable.generated.swift
//
// swiftlint:disable line_length
// swiftlint:disable variable_name
// swiftlint:disable vertical_whitespace

import Foundation
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif


@testable import DuckDuckGo_Privacy_Browser














final class AppearancePreferencesPersistorMock: AppearancePreferencesPersistor {
    var showFullURL: Bool {
        get { return underlyingShowFullURL }
        set(value) { underlyingShowFullURL = value }
    }
    var underlyingShowFullURL: Bool!
    var currentThemeName: String {
        get { return underlyingCurrentThemeName }
        set(value) { underlyingCurrentThemeName = value }
    }
    var underlyingCurrentThemeName: String!

}
final class AutofillPreferencesPersistorMock: AutofillPreferencesPersistor {
    var isAutoLockEnabled: Bool {
        get { return underlyingIsAutoLockEnabled }
        set(value) { underlyingIsAutoLockEnabled = value }
    }
    var underlyingIsAutoLockEnabled: Bool!
    var autoLockThreshold: AutofillAutoLockThreshold {
        get { return underlyingAutoLockThreshold }
        set(value) { underlyingAutoLockThreshold = value }
    }
    var underlyingAutoLockThreshold: AutofillAutoLockThreshold!
    var askToSaveUsernamesAndPasswords: Bool {
        get { return underlyingAskToSaveUsernamesAndPasswords }
        set(value) { underlyingAskToSaveUsernamesAndPasswords = value }
    }
    var underlyingAskToSaveUsernamesAndPasswords: Bool!
    var askToSaveAddresses: Bool {
        get { return underlyingAskToSaveAddresses }
        set(value) { underlyingAskToSaveAddresses = value }
    }
    var underlyingAskToSaveAddresses: Bool!
    var askToSavePaymentMethods: Bool {
        get { return underlyingAskToSavePaymentMethods }
        set(value) { underlyingAskToSavePaymentMethods = value }
    }
    var underlyingAskToSavePaymentMethods: Bool!

}
final class DefaultBrowserProviderMock: DefaultBrowserProvider {
    var bundleIdentifier: String {
        get { return underlyingBundleIdentifier }
        set(value) { underlyingBundleIdentifier = value }
    }
    var underlyingBundleIdentifier: String!
    var isDefault: Bool {
        get { return underlyingIsDefault }
        set(value) { underlyingIsDefault = value }
    }
    var underlyingIsDefault: Bool!

    // MARK: - presentDefaultBrowserPrompt

    var presentDefaultBrowserPromptThrowableError: Error?
    var presentDefaultBrowserPromptCallsCount = 0
    var presentDefaultBrowserPromptCalled: Bool {
        return presentDefaultBrowserPromptCallsCount > 0
    }
    var presentDefaultBrowserPromptClosure: (() throws -> Void)?

    func presentDefaultBrowserPrompt() throws {
        presentDefaultBrowserPromptCallsCount += 1
        if let error = presentDefaultBrowserPromptThrowableError {
            throw error
        }
        try presentDefaultBrowserPromptClosure?()
    }

    // MARK: - openSystemPreferences

    var openSystemPreferencesCallsCount = 0
    var openSystemPreferencesCalled: Bool {
        return openSystemPreferencesCallsCount > 0
    }
    var openSystemPreferencesClosure: (() -> Void)?

    func openSystemPreferences() {
        openSystemPreferencesCallsCount += 1
        openSystemPreferencesClosure?()
    }

}
final class DownloadsPreferencesPersistorMock: DownloadsPreferencesPersistor {
    var selectedDownloadLocation: String?
    var alwaysRequestDownloadLocation: Bool {
        get { return underlyingAlwaysRequestDownloadLocation }
        set(value) { underlyingAlwaysRequestDownloadLocation = value }
    }
    var underlyingAlwaysRequestDownloadLocation: Bool!
    var defaultDownloadLocation: URL?

    // MARK: - isDownloadLocationValid

    var isDownloadLocationValidCallsCount = 0
    var isDownloadLocationValidCalled: Bool {
        return isDownloadLocationValidCallsCount > 0
    }
    var isDownloadLocationValidReceivedLocation: URL?
    var isDownloadLocationValidReceivedInvocations: [URL] = []
    var isDownloadLocationValidReturnValue: Bool!
    var isDownloadLocationValidClosure: ((URL) -> Bool)?

    func isDownloadLocationValid(_ location: URL) -> Bool {
        isDownloadLocationValidCallsCount += 1
        isDownloadLocationValidReceivedLocation = location
        isDownloadLocationValidReceivedInvocations.append(location)
        if let isDownloadLocationValidClosure = isDownloadLocationValidClosure {
            return isDownloadLocationValidClosure(location)
        } else {
            return isDownloadLocationValidReturnValue
        }
    }

}
final class UserAuthenticatingMock: UserAuthenticating {

    // MARK: - authenticateUser

    var authenticateUserReasonResultCallsCount = 0
    var authenticateUserReasonResultCalled: Bool {
        return authenticateUserReasonResultCallsCount > 0
    }
    var authenticateUserReasonResultReceivedArguments: (reason: DeviceAuthenticator.AuthenticationReason, result: (DeviceAuthenticationResult) -> Void)?
    var authenticateUserReasonResultReceivedInvocations: [(reason: DeviceAuthenticator.AuthenticationReason, result: (DeviceAuthenticationResult) -> Void)] = []
    var authenticateUserReasonResultClosure: ((DeviceAuthenticator.AuthenticationReason, @escaping (DeviceAuthenticationResult) -> Void) -> Void)?

    func authenticateUser(reason: DeviceAuthenticator.AuthenticationReason, result: @escaping (DeviceAuthenticationResult) -> Void) {
        authenticateUserReasonResultCallsCount += 1
        authenticateUserReasonResultReceivedArguments = (reason: reason, result: result)
        authenticateUserReasonResultReceivedInvocations.append((reason: reason, result: result))
        authenticateUserReasonResultClosure?(reason, result)
    }

}
