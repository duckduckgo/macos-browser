//
//  OnboardingUserScript.swift
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

import BrowserServicesKit
import Configuration
import WebKit
import Common
import UserScript

final class OnboardingUserScript: NSObject, Subfeature {

    let messageOriginPolicy: MessageOriginPolicy = .all
    let featureName: String = "onboarding"
    var broker: UserScriptMessageBroker?

    // MARK: - Subfeature
    public func with(broker: UserScriptMessageBroker) {
        self.broker = broker
    }

    // MARK: - MessageNames
    enum MessageNames: String, CaseIterable {
        case setBlockCookiePopups
        case setDuckPlayer
        case setBookmarksBar
        case setSessionRestore
        case setShowHomeButton
        case requestRemoveFromDock
        case requestImport
        case requestSetAsDefault
        case dismiss
        case dismissToSettings
        case dismissToAddressBar
        case reportPageException
    }

    func handler(forMethodNamed methodName: String) -> Subfeature.Handler? {
        switch MessageNames(rawValue: methodName) {
        case .setDuckPlayer:
            return setDuckPlayer
        case .setBookmarksBar:
            return setBookmarksBar
        case .setSessionRestore:
            return setSessionRestore
        case .setShowHomeButton:
            return setShowHome
        case .requestImport:
            return requestImport
        case .requestSetAsDefault:
            return requestSetAsDefault
        case .requestRemoveFromDock:
            return requestRemoveFromDock
        case .setBlockCookiePopups:
            return setBlockCookiePopups
        case .dismissToAddressBar:
            return dismissToAddressBar
        case .dismissToSettings:
            return dismissToSettings
        case .reportPageException:
            return reportPageException
        default:
            print(methodName)
            //            assertionFailure("PrivacyConfigurationEditUserScript: Failed to parse User Script message: \(methodName)")
            return nil
        }
    }

    struct BooleanParams: Codable {
        let enabled: Bool
    }

    struct StringParams: Codable {
        let value: String
    }

    func parse(params: Any) -> BooleanParams? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(BooleanParams.self, from: data) else {
            return nil
        }
        return result
    }

    @MainActor
    func setDuckPlayer(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let params = parse(params: params)
        guard params?.enabled == true else { return nil }

        DuckPlayerPreferences.shared.duckPlayerMode = .enabled
        return nil
    }

    @MainActor
    func setBookmarksBar(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let params: BooleanParams = DecodableHelper.decode(from: params) else { return nil }
        AppearancePreferences.shared.showBookmarksBar = params.enabled
        return nil
    }

    @MainActor
    func setSessionRestore(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let params: BooleanParams = DecodableHelper.decode(from: params) else { return nil }
        StartupPreferences.shared.restorePreviousSession = params.enabled
        return nil
    }

    @MainActor
    func setBlockCookiePopups(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let params = parse(params: params)
        guard params?.enabled == true else { return nil }

        PrivacySecurityPreferences.shared.autoconsentEnabled = true
        return nil
    }

    enum ShowHomeValue: String, Decodable {
        case hidden;
        case left;
        case right;
    }

    struct ShowHomeParams: Decodable {
        let value: ShowHomeValue
    }

    @MainActor
    func setShowHome(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let params: ShowHomeParams = DecodableHelper.decode(from: params),
              let value = HomeButtonPosition(rawValue: params.value.rawValue)
        else { return nil }

        StartupPreferences.shared.homeButtonPosition = value
        StartupPreferences.shared.updateHomeButton()
        return nil
    }

    @MainActor
    func requestImport(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let response: Response = try await withCheckedThrowingContinuation { continuation in
            DataImportView.show {
                let response = Response()
                continuation.resume(returning: response)
            }
        }
        return response
    }

    struct Response: Encodable {
    }

    @MainActor
    func requestSetAsDefault(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let defaultBrowserPreferences = DefaultBrowserPreferences()
        if defaultBrowserPreferences.isDefault {
            return Response()
        }

        let response: Response = try await withCheckedThrowingContinuation { continuation in
            defaultBrowserPreferences.becomeDefault { _ in
                _ = defaultBrowserPreferences
                let response = Response()
                continuation.resume(returning: response)
            }
        }
        return response
    }

    @MainActor
    func requestRemoveFromDock(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        print("todo: requestRemoveFromDock...")
        return Response()
    }

    @MainActor
    func dismissToAddressBar(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let mainVC = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController else { return nil }
        mainVC.navigationBarViewController.addressBarViewController?.addressBarTextField.stringValue = ""
        mainVC.navigationBarViewController.addressBarViewController?.addressBarTextField.makeMeFirstResponder()
        return nil
    }

    @MainActor
    func dismissToSettings(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        print("todo: dismissToSettings pixel?")
        return nil
    }

    struct PageException: Decodable {
        let message: String
        let page: String
    }

    struct InitException: Decodable {
        let message: String
        let page: String
    }

    @MainActor
    func reportPageException(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let exception: PageException = DecodableHelper.decode(from: params) else { return nil }
        print("todo: reportPageException pixel?")
        return nil
    }

    @MainActor
    func reportInitException(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let exception: InitException = DecodableHelper.decode(from: params) else { return nil }
        print("todo: reportInitException pixel?")
        return nil
    }
}

struct DecodableHelper {
    public static func decode<Input: Any, Target: Decodable>(from input: Input) -> Target? {
        do {
            let json = try JSONSerialization.data(withJSONObject: input)
            return try JSONDecoder().decode(Target.self, from: json)
        } catch let error as DecodingError {
            switch error {
            case .typeMismatch(let type, let context):
                os_log(.error, "DecodableHelper: Type Mismatch for type \(type): \(context.debugDescription) \(context.codingPath)")
            case .valueNotFound(let type, let context):
                os_log(.error, "DecodableHelper: Value not found for type \(type): \(context.debugDescription) \(context.codingPath)")
            case .keyNotFound(let key, let context):
                os_log(.error, "DecodableHelper: Key not found \(key): \(context.debugDescription) \(context.codingPath)")
            case .dataCorrupted(let context):
                os_log(.error, "DecodableHelper: Data corrupted: \(context.debugDescription) \(context.codingPath)")
            default:
                os_log(.error, "DecodableHelper: Error decoding message body: %{public}@", error.localizedDescription)
            }
            return nil
        } catch {
            os_log(.error, "DecodableHelper: Unknown error: %{public}@", error.localizedDescription)
            return nil
        }

    }
}
