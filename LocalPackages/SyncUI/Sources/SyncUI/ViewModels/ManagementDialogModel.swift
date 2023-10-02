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
    var isUnifiedFavoritesEnabled: Bool { get set }

    func recoverDevice(using recoveryCode: String)
    func saveRecoveryPDF()
    func turnOffSync()
    func updateDeviceName(_ name: String)
    func removeDevice(_ device: SyncDevice)
    func deleteAccount()
    func presentSaveRecoveryPDF()
}

public final class ManagementDialogModel: ObservableObject {

    @Published public var currentDialog: ManagementDialogKind?
    public var codeToDisplay: String?

    @Published public var shouldShowErrorMessage: Bool = false
    @Published public var errorMessage: String?
    @Published public var isUnifiedFavoritesEnabled: Bool = false {
        didSet {
            if delegate?.isUnifiedFavoritesEnabled != isUnifiedFavoritesEnabled {
                delegate?.isUnifiedFavoritesEnabled = isUnifiedFavoritesEnabled
            }
        }
    }

    public weak var delegate: ManagementDialogModelDelegate?

    public init() {
        shouldShowErrorMessageCancellable = $errorMessage
            .map { $0 != nil }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasError in
                self?.shouldShowErrorMessage = hasError
            }
    }

    public func endFlow() {
        currentDialog = nil
    }

    private var shouldShowErrorMessageCancellable: AnyCancellable?
}
