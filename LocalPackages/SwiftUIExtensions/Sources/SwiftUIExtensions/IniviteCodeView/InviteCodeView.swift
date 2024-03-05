//
//  InviteCodeView.swift
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

public struct InviteCodeView<ViewModel>: View where ViewModel: InviteCodeViewModel {
    @ObservedObject public var viewModel: ViewModel

    public init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Dialog {
            VStack(spacing: 20) {
                Image(.inviteLock96)
                Text(viewModel.titleText)
                    .font(.system(size: 17, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                Text(viewModel.messageText)
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                if viewModel.showProgressView {
                    ProgressView()
                } else {
                    TextField(viewModel.textFieldPlaceholder, text: $viewModel.textFieldText, onCommit: {
                        Task {
                            await viewModel.onConfirm()
                        }
                    })
                    .frame(width: 96)
                    .textFieldStyle(.roundedBorder)
                }
                if let errorText = viewModel.errorText {
                    Text(errorText)
                        .font(.system(size: 13))
                        .foregroundColor(Color(.alertRedLightDefaultText))
                        .multilineTextAlignment(.center)
                }
            }
        } buttons: {
            Button(viewModel.cancelButtonText) {
                viewModel.onCancel()
            }
            Button(viewModel.confirmButtonText) {
                Task {
                    await viewModel.onConfirm()
                }
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
        .frame(width: 320)
    }
}

public protocol InviteCodeViewModel: ObservableObject {

    var titleText: String { get }
    var messageText: String { get }
    var textFieldPlaceholder: String { get }
    var cancelButtonText: String { get }
    var confirmButtonText: String { get }

    var textFieldText: String { get set }
    var errorText: String? { get set }

    var showProgressView: Bool { get set }

    func onConfirm() async
    func onCancel()

}

public struct InviteCodeSuccessView<ViewModel>: View where ViewModel: InviteCodeSuccessViewModel {
    @ObservedObject public var viewModel: ViewModel

    public init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Dialog {
            VStack(spacing: 20) {
                Image(.intiveLockSucces96)
                Text(viewModel.titleText)
                    .font(.system(size: 17, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                Text(viewModel.messageText).font(.system(size: 13)).multilineTextAlignment(.center)
            }
        } buttons: {
            Button(viewModel.confirmButtonText) {
                viewModel.onConfirm()
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
        .frame(width: 320)
    }
}

public protocol InviteCodeSuccessViewModel: ObservableObject {

    var titleText: String { get }
    var messageText: String { get }
    var confirmButtonText: String { get }

    func onConfirm()

}
