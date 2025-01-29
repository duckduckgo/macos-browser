//
//  ManagementDialogModel.swift
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
import Combine

public protocol ManagementDialogModelDelegate: AnyObject {
    func recoverDevice(recoveryCode: String, fromRecoveryScreen: Bool)
    func turnOffSync()
    func updateDeviceName(_ name: String)
    func removeDevice(_ device: SyncDevice)
    func deleteAccount()
    func recoveryCodePasted(_ code: String, fromRecoveryScreen: Bool)
    func saveRecoveryPDF()
    func recoveryCodeNextPressed()
    func turnOnSync()
    func recoveryCodePasted(_ code: String)
    func enterRecoveryCodePressed()
    func copyCode()
    func openSystemPasswordSettings()
    func userConfirmedSwitchAccounts(recoveryCode: String)
    func switchAccountsCancelled()
}

public final class ManagementDialogModel: ObservableObject {

    @Published public var currentDialog: ManagementDialogKind?
    public var codeToDisplay: String?

    @Published public var shouldShowErrorMessage: Bool = false
    @Published public var syncErrorMessage: SyncErrorMessage?
    @Published public var shouldShowSwitchAccountsMessage: Bool = false

    private(set) public var codeToSwitchTo: String?

    public weak var delegate: ManagementDialogModelDelegate?

    public init() {
        shouldShowErrorMessageCancellable = $syncErrorMessage
            .map { $0 != nil }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasError in
                self?.shouldShowErrorMessage = hasError
            }

    }

    @MainActor
    public func endFlow() {
        if shouldShowSwitchAccountsMessage {
            delegate?.switchAccountsCancelled()
        }
        doEndFlow()
    }

    @MainActor
    public func userConfirmedSwitchAccounts(recoveryCode: String) {
        delegate?.userConfirmedSwitchAccounts(recoveryCode: recoveryCode)
    }

    @MainActor
    public func showSwitchAccountsMessage() {
        shouldShowSwitchAccountsMessage = true
        shouldShowErrorMessage = true
    }

    @MainActor
    private func doEndFlow() {
        syncErrorMessage?.type.onButtonPressed(delegate: delegate)
        syncErrorMessage = nil
        currentDialog = nil
    }

    private var shouldShowErrorMessageCancellable: AnyCancellable?
}
