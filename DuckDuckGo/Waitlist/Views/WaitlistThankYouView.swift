//
//  WaitlistThankYouView.swift
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
import Combine
import SwiftUI

// MARK: - Model

struct WaitlistBetaThankYouCopy {
    static let vpn = WaitlistBetaThankYouCopy(
        title: UserText.vpnThankYouTitle,
        subtitle: UserText.vpnThankYouSubtitle,
        body1: UserText.vpnThankYouBody1,
        body2: UserText.vpnThankYouBody2
    )

    let title: String
    let subtitle: String
    let body1: String
    let body2: String

    @available(macOS 12.0, *)
    func boldedBold1() -> AttributedString {
        return bolded(text: body1, boldedStrings: ["THANKYOU"])
    }

    @available(macOS 12.0, *)
    func boldedBold2() -> AttributedString {
        return bolded(text: body2, boldedStrings: ["duckduckgo.com/app"])
    }

    @available(macOS 12.0, *)
    private func bolded(text: String, boldedStrings: [String]) -> AttributedString {
        var attributedString = AttributedString(text)

        for boldedString in boldedStrings {
            if let range = attributedString.range(of: boldedString) {
                attributedString[range].font = .system(size: 14, weight: .semibold)
            }
        }

        return attributedString
    }
}

// MARK: - View Model

protocol WaitlistBetaThankYouDialogViewModelDelegate: AnyObject {
    func waitlistBetaThankYouViewModelDismissedView(_ viewModel: WaitlistBetaThankYouDialogViewModel)
}

final class WaitlistBetaThankYouDialogViewModel: ObservableObject {

    enum ViewAction {
        case close
    }

    weak var delegate: WaitlistBetaThankYouDialogViewModelDelegate?

    init() {}

    @MainActor
    func process(action: ViewAction) async {
        switch action {
        case .close:
            delegate?.waitlistBetaThankYouViewModelDismissedView(self)
        }
    }

}

// MARK: - View

final class WaitlistBetaThankYouDialogViewController: NSViewController {

    private let defaultSize = CGSize(width: 360, height: 498)
    private let viewModel: WaitlistBetaThankYouDialogViewModel

    private var heightConstraint: NSLayoutConstraint?
    private var cancellables = Set<AnyCancellable>()

    private let copy: WaitlistBetaThankYouCopy

    init(copy: WaitlistBetaThankYouCopy) {
        self.viewModel = WaitlistBetaThankYouDialogViewModel()
        self.copy = copy
        super.init(nibName: nil, bundle: nil)
        self.viewModel.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(origin: CGPoint.zero, size: defaultSize))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let feedbackFormView = WaitlistBetaThankYouView(copy: self.copy)
        let hostingView = NSHostingView(rootView: feedbackFormView.environmentObject(self.viewModel))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingView)

        let heightConstraint = hostingView.heightAnchor.constraint(equalToConstant: defaultSize.height)
        self.heightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            heightConstraint,
            hostingView.widthAnchor.constraint(equalToConstant: defaultSize.width),
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingView.leftAnchor.constraint(equalTo: view.leftAnchor),
            hostingView.rightAnchor.constraint(equalTo: view.rightAnchor)
        ])
    }

}

struct WaitlistBetaThankYouView: View {

    @EnvironmentObject var viewModel: WaitlistBetaThankYouDialogViewModel

    let copy: WaitlistBetaThankYouCopy

    var body: some View {
        VStack(spacing: 0) {
            VStack {
                Text(copy.title)
                    .font(.system(size: 17, weight: .semibold))
                    .padding([.leading, .trailing], 21.5)
                    .padding([.top, .bottom], 24)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .background(Color.backgroundSecondary)

            Divider()

            Image("Gift-96")
                .resizable()
                .frame(width: 96, height: 96)
                .padding([.top, .bottom], 24)

            Text(copy.subtitle)
                .font(.system(size: 17, weight: .semibold))
                .padding([.leading, .trailing, .bottom], 14)

            if #available(macOS 12.0, *) {
                Text(copy.boldedBold1())
                    .font(.system(size: 14))
                    .padding([.leading, .trailing, .bottom], 14)
                    .lineSpacing(2)
            } else {
                Text(copy.body1)
                    .font(.system(size: 14))
                    .padding([.leading, .trailing, .bottom], 14)
                    .lineSpacing(2)
            }

            if #available(macOS 12.0, *) {
                Text(copy.boldedBold2())
                    .font(.system(size: 14))
                    .padding([.leading, .trailing, .bottom], 14)
                    .lineSpacing(2)
            } else {
                Text(copy.body2)
                    .font(.system(size: 14))
                    .padding([.leading, .trailing, .bottom], 14)
                    .lineSpacing(2)
            }

            Spacer()

            button(text: "Close", action: .close)
                .padding(16)
        }
        .multilineTextAlignment(.center)
    }

    @ViewBuilder
    func button(text: String, action: WaitlistBetaThankYouDialogViewModel.ViewAction) -> some View {
        Button(action: {
            Task {
                await viewModel.process(action: action)
            }
        }, label: {
            Text(text)
                .frame(maxWidth: .infinity)
        })
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
        .frame(maxWidth: .infinity)
    }

}

extension WaitlistBetaThankYouDialogViewController: WaitlistBetaThankYouDialogViewModelDelegate {

    func waitlistBetaThankYouViewModelDismissedView(_ viewModel: WaitlistBetaThankYouDialogViewModel) {
        dismiss()
    }

}
