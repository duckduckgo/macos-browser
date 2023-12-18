//
//  DataBrokerProtectionInviteDialogsView.swift
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

enum DataBrokerProtectionInviteDialogKind {
    case codeEntry, success
}

public struct DataBrokerProtectionInviteDialogsView: View {

    @ObservedObject var viewModel: DataBrokerProtectionInviteDialogsViewModel

    public init(viewModel: DataBrokerProtectionInviteDialogsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        switch viewModel.currentDialogKind {
        case .codeEntry:
            let codeViewModel = DataBrokerProtectionInviteCodeViewModel(delegate: viewModel)
            InviteCodeView(viewModel: codeViewModel)
        case .success:
            let successViewModel = DataBrokerProtectionInviteCodeSuccessViewModel(delegate: viewModel)
            InviteCodeSuccessView(viewModel: successViewModel)
        }
    }
}

public protocol DataBrokerProtectionInviteDialogsViewModelDelegate: AnyObject {
    func dataBrokerProtectionInviteDialogsViewModelDidReedemSuccessfully(_ viewModel: DataBrokerProtectionInviteDialogsViewModel)
    func dataBrokerProtectionInviteDialogsViewModelDidCancel(_ viewModel: DataBrokerProtectionInviteDialogsViewModel)
}

public final class DataBrokerProtectionInviteDialogsViewModel: ObservableObject {
    @Published var currentDialogKind: DataBrokerProtectionInviteDialogKind = .codeEntry
    private weak var delegate: DataBrokerProtectionInviteDialogsViewModelDelegate?

    public init(delegate: DataBrokerProtectionInviteDialogsViewModelDelegate) {
        self.delegate = delegate
    }
}

extension DataBrokerProtectionInviteDialogsViewModel: DataBrokerProtectionInviteCodeViewModelDelegate {
    func dataBrokerProtectionInviteCodeViewModelDidReedemSuccessfully(_ viewModel: DataBrokerProtectionInviteCodeViewModel) {
        currentDialogKind = .success
    }

    func dataBrokerProtectionInviteCodeViewModelDidCancel(_ viewModel: DataBrokerProtectionInviteCodeViewModel) {
        delegate?.dataBrokerProtectionInviteDialogsViewModelDidCancel(self)
    }
}

extension DataBrokerProtectionInviteDialogsViewModel: DataBrokerProtectionInviteCodeSuccessViewModelDelegate {
    func dataBrokerProtectionInviteCodeSuccessViewModelDidConfirm(_ viewModel: DataBrokerProtectionInviteCodeSuccessViewModel) {
        delegate?.dataBrokerProtectionInviteDialogsViewModelDidReedemSuccessfully(self)
    }
}
