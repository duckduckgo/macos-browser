//
//  NetworkProtectionInviteCodeViewModel.swift
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

#if NETWORK_PROTECTION

import Combine
import NetworkProtection
import SwiftUIExtensions

enum NetworkProtectionInviteDialogKind {
    case codeEntry, success
}

protocol NetworkProtectionInviteViewModelDelegate: AnyObject {
    func didCancelInviteFlow()
    func didCompleteInviteFlow()
}

final class NetworkProtectionInviteViewModel: ObservableObject {

    @Published var currentDialog: NetworkProtectionInviteDialogKind? = .codeEntry
    let inviteCodeViewModel: NetworkProtectionInviteCodeViewModel
    let successCodeViewModel: NetworkProtectionInviteSuccessViewModel

    private weak var delegate: NetworkProtectionInviteViewModelDelegate?

    init(delegate: NetworkProtectionInviteViewModelDelegate, redemptionCoordinator: NetworkProtectionCodeRedeeming) {
        self.delegate = delegate
        inviteCodeViewModel = NetworkProtectionInviteCodeViewModel(redemptionCoordinator: redemptionCoordinator)
        successCodeViewModel = NetworkProtectionInviteSuccessViewModel()

        inviteCodeViewModel.delegate = self
        successCodeViewModel.delegate = self
    }

    func getStarted() {
        delegate?.didCompleteInviteFlow()
    }

    func cancel() {
        delegate?.didCancelInviteFlow()
        currentDialog = nil
    }
}

extension NetworkProtectionInviteViewModel: NetworkProtectionInviteCodeViewModelDelegate {

    func networkProtectionInviteCodeViewModelDidReedemSuccessfully(_ viewModel: NetworkProtectionInviteCodeViewModel) {
        currentDialog = .success
    }

    func networkProtectionInviteCodeViewModelDidCancel(_ viewModel: NetworkProtectionInviteCodeViewModel) {
        delegate?.didCancelInviteFlow()
        currentDialog = nil
    }
}

extension NetworkProtectionInviteViewModel: NetworkProtectionInviteSuccessViewModelDelegate {

    func networkProtectionInviteSuccessViewModelDidConfirm(_ viewModel: NetworkProtectionInviteSuccessViewModel) {
        delegate?.didCompleteInviteFlow()
    }
}

protocol NetworkProtectionInviteCodeViewModelDelegate: AnyObject {
    func networkProtectionInviteCodeViewModelDidReedemSuccessfully(_ viewModel: NetworkProtectionInviteCodeViewModel)
    func networkProtectionInviteCodeViewModelDidCancel(_ viewModel: NetworkProtectionInviteCodeViewModel)
}

final class NetworkProtectionInviteCodeViewModel: InviteCodeViewModel {

    weak var delegate: NetworkProtectionInviteCodeViewModelDelegate?

    var titleText: String {
        UserText.networkProtectionInviteDialogTitle
    }

    var messageText: String {
        UserText.networkProtectionInviteDialogMessage
    }

    var textFieldPlaceholder: String {
        UserText.networkProtectionInviteFieldPrompt
    }

    var cancelButtonText: String {
        UserText.cancel
    }

    var confirmButtonText: String {
        UserText.continue
    }

    @Published var textFieldText: String = "" {
        didSet {
            if oldValue != textFieldText {
                textFieldText = textFieldText.uppercased()
            }
        }
    }

    @Published var errorText: String?

    private let redemptionCoordinator: NetworkProtectionCodeRedeeming
    private var textCancellable: AnyCancellable?

    init(redemptionCoordinator: NetworkProtectionCodeRedeeming) {
        self.redemptionCoordinator = redemptionCoordinator
        textCancellable = $textFieldText.sink { [weak self] _ in
            self?.errorText = nil
        }
    }

    @MainActor
    func onConfirm() async {
        errorText = nil
        do {
            try await redemptionCoordinator.redeem(textFieldText.trimmingWhitespace())
        } catch NetworkProtectionClientError.invalidInviteCode {
            errorText = UserText.inviteDialogUnrecognizedCodeMessage
            return
        } catch {
            errorText = UserText.unknownErrorTryAgainMessage
            return
        }
        delegate?.networkProtectionInviteCodeViewModelDidReedemSuccessfully(self)
    }

    func onCancel() {
        delegate?.networkProtectionInviteCodeViewModelDidCancel(self)
    }

}

protocol NetworkProtectionInviteSuccessViewModelDelegate: AnyObject {
    func networkProtectionInviteSuccessViewModelDidConfirm(_ viewModel: NetworkProtectionInviteSuccessViewModel)
}

final class NetworkProtectionInviteSuccessViewModel: InviteCodeSuccessViewModel {
    
    weak var delegate: NetworkProtectionInviteSuccessViewModelDelegate?
    
    var titleText: String {
        UserText.networkProtectionInviteSuccessTitle
    }
    
    var messageText: String {
        UserText.networkProtectionInviteSuccessMessage
    }
    
    var confirmButtonText: String {
        UserText.inviteDialogGetStartedButton
    }
    
    func onConfirm() {
        delegate?.networkProtectionInviteSuccessViewModelDidConfirm(self)
    }
    
}

#endif
