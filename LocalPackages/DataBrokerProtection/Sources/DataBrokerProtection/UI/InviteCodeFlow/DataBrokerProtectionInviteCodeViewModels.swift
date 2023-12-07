//
//  DataBrokerProtectionInviteCodeViewModels.swift
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

import SwiftUI
import SwiftUIExtensions

protocol DataBrokerProtectionInviteCodeViewModelDelegate: AnyObject {
    func dataBrokerProtectionInviteCodeViewModelDidReedemSuccessfully(_ viewModel: DataBrokerProtectionInviteCodeViewModel)
    func dataBrokerProtectionInviteCodeViewModelDidCancel(_ viewModel: DataBrokerProtectionInviteCodeViewModel)
}

final class DataBrokerProtectionInviteCodeViewModel: InviteCodeViewModel {

    private let redeemUseCase: DataBrokerProtectionRedeemUseCase
    private weak var delegate: DataBrokerProtectionInviteCodeViewModelDelegate?

    var titleText: String {
        "Personal Information Removal"
    }

    var messageText: String {
        "Enter your Invite Code to get started."
    }

    var textFieldPlaceholder: String {
        "Code"
    }

    var cancelButtonText: String {
        "Cancel"
    }

    var confirmButtonText: String {
        "Continue"
    }

    @Published var textFieldText: String = "" {
        didSet {
            if oldValue != textFieldText {
                textFieldText = textFieldText.uppercased()
            }
        }
    }

    private let errorMessageText: String = "We didn’t recognize this Invite Code."

    @Published var errorText: String?

    @Published var showProgressView = false

    init(delegate: DataBrokerProtectionInviteCodeViewModelDelegate,
         authenticationRepository: AuthenticationRepository = KeychainAuthenticationData(),
         authenticationService: DataBrokerProtectionAuthenticationService = AuthenticationService()) {
        self.delegate = delegate
        self.redeemUseCase = RedeemUseCase(authenticationService: authenticationService, authenticationRepository: authenticationRepository)
    }

    @MainActor
    func onConfirm() async {
        errorText = nil
        showProgressView = true
        do {
            try await redeemUseCase.redeem(inviteCode: textFieldText)
        } catch {
            errorText = errorMessageText
            showProgressView = false
            return
        }
        showProgressView = false
        delegate?.dataBrokerProtectionInviteCodeViewModelDidReedemSuccessfully(self)
    }

    func onCancel() {
        delegate?.dataBrokerProtectionInviteCodeViewModelDidCancel(self)
    }
}

protocol DataBrokerProtectionInviteCodeSuccessViewModelDelegate: AnyObject {
    func dataBrokerProtectionInviteCodeSuccessViewModelDidConfirm(_ viewModel: DataBrokerProtectionInviteCodeSuccessViewModel)
}

final class DataBrokerProtectionInviteCodeSuccessViewModel: InviteCodeSuccessViewModel {

    private weak var delegate: DataBrokerProtectionInviteCodeSuccessViewModelDelegate?

    var titleText: String {
        "Personal Information Removal"
    }

    var messageText: String {
        "Data brokers and people-search sites publish personal info online. Discover where you’re exposed and automatically remove"
    }

    var confirmButtonText: String {
        "Continue"
    }

    init(delegate: DataBrokerProtectionInviteCodeSuccessViewModelDelegate) {
        self.delegate = delegate
    }

    func onConfirm() {
        delegate?.dataBrokerProtectionInviteCodeSuccessViewModelDidConfirm(self)
    }
}
