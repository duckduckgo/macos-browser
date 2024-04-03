//
//  ManagementViewModel.swift
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

public protocol ManagementViewModel: ObservableObject {

    var isDataSyncingAvailable: Bool { get }
    var isConnectingDevicesAvailable: Bool { get }
    var isAccountCreationAvailable: Bool { get }
    var isAccountRecoveryAvailable: Bool { get }
    var isAppVersionNotSupported: Bool { get }

    var isSyncEnabled: Bool { get }
    var isCreatingAccount: Bool { get }
    var shouldShowErrorMessage: Bool { get set }
    var syncErrorMessage: SyncErrorMessage? { get }
    var isSyncBookmarksPaused: Bool { get }
    var isSyncCredentialsPaused: Bool { get }

    var invalidBookmarksTitles: [String] { get }
    var invalidCredentialsTitles: [String] { get }

    var recoveryCode: String? { get }
    var codeToDisplay: String? { get }
    var devices: [SyncDevice] { get }
    var isFaviconsFetchingEnabled: Bool { get set }
    var isUnifiedFavoritesEnabled: Bool { get set }

    func presentDeleteAccount()
    func presentDeviceDetails(_ device: SyncDevice)
    func presentRemoveDevice(_ device: SyncDevice)

    func saveRecoveryPDF()
    func refreshDevices()

    func manageBookmarks()
    func manageLogins()

    func syncWithAnotherDevicePressed() async
    func syncWithServerPressed() async
    func recoverDataPressed() async
    func turnOffSyncPressed()
}

public enum SyncErrorType {
    case unableToSyncToServer
    case unableToSyncToOtherDevice
    case unableToMergeTwoAccounts
    case unableToUpdateDeviceName
    case unableToTurnSyncOff
    case unableToDeleteData
    case unableToRemoveDevice
    case invalidCode
    case unableCreateRecoveryPDF

    var title: String {
        return UserText.syncErrorAlertTitle
    }

    var description: String {
        switch self {
        case .unableToSyncToServer:
            return UserText.unableToSyncToServerDescription
        case .unableToSyncToOtherDevice:
            return UserText.unableToSyncWithAnotherDeviceDescription
        case .unableToMergeTwoAccounts:
            return UserText.unableToMergeTwoAccountsDescription
        case .unableToUpdateDeviceName:
            return UserText.unableToUpdateDeviceNameDescription
        case .unableToTurnSyncOff:
            return UserText.unableToTurnSyncOffDescription
        case .unableToDeleteData:
            return UserText.unableToDeleteDataDescription
        case .unableToRemoveDevice:
            return UserText.unableToRemoveDeviceDescription
        case .invalidCode:
            return UserText.invalidCodeDescription
        case .unableCreateRecoveryPDF:
            return UserText.unableCreateRecoveryPdfDescription
        }
    }
}

public struct SyncErrorMessage {
    var type: SyncErrorType
    var errorDescription: String

    public init(type: SyncErrorType, description: String) {
        self.type = type
        self.errorDescription = description
    }
}
