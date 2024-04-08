//
//  BookmarkDialogButtonsView.swift
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

import SwiftUI

struct BookmarkDialogButtonsView: View {
    private let viewState: ViewState
    private let otherButtonAction: Action
    private let defaultButtonAction: Action
    @Environment(\.dismiss) private var dismiss

    init(
        viewState: ViewState,
        otherButtonAction: Action,
        defaultButtonAction: Action
    ) {
        self.viewState = viewState
        self.otherButtonAction = otherButtonAction
        self.defaultButtonAction = defaultButtonAction
    }

    var body: some View {
        HStack {
            if viewState == .compressed {
                Spacer()
            }

            actionButton(action: otherButtonAction, viewState: viewState).accessibilityIdentifier("BookmarkDialogButtonsView.otherButton")

            actionButton(action: defaultButtonAction, viewState: viewState).accessibilityIdentifier("BookmarkDialogButtonsView.defaultButton")
        }
    }

    @MainActor
    private func actionButton(action: Action, viewState: ViewState) -> some View {
        Button {
            action.action(dismiss.callAsFunction)
        } label: {
            Text(action.title)
                .frame(height: viewState.height)
                .frame(maxWidth: viewState.maxWidth)
        }
        .keyboardShortcut(action.keyboardShortCut)
        .disabled(action.isDisabled)
        .ifLet(action.accessibilityIdentifier) { view, value in
            view.accessibilityIdentifier(value)
        }
    }
}

// MARK: - BookmarkDialogButtonsView + Types

extension BookmarkDialogButtonsView {

    enum ViewState: Equatable {
        case compressed
        case expanded
    }

    struct Action {
        let title: String
        let keyboardShortCut: KeyboardShortcut?
        let accessibilityIdentifier: String?
        let isDisabled: Bool
        let action: @MainActor (_ dismiss: () -> Void) -> Void

        init(
            title: String,
            accessibilityIdentifier: String? = nil,
            keyboardShortCut: KeyboardShortcut? = nil,
            isDisabled: Bool  = false,
            action: @MainActor @escaping (_ dismiss: () -> Void) -> Void
        ) {
            self.title = title
            self.keyboardShortCut = keyboardShortCut
            self.accessibilityIdentifier = accessibilityIdentifier
            self.isDisabled = isDisabled
            self.action = action
        }
    }
}

// MARK: - BookmarkDialogButtonsView.ViewState

private extension BookmarkDialogButtonsView.ViewState {

    var maxWidth: CGFloat? {
        switch self {
        case .compressed:
            return nil
        case .expanded:
            return .infinity
        }
    }

    var height: CGFloat? {
        switch self {
        case .compressed:
            return nil
        case .expanded:
            return 28.0
        }
    }

}

// MARK: - Preview

#Preview("Compressed - Disable Default Button") {
    BookmarkDialogButtonsView(
        viewState: .compressed,
        otherButtonAction: .init(
            title: "Left",
            action: { _ in }
        ),
        defaultButtonAction: .init(
            title: "Right",
            isDisabled: true,
            action: {_ in }
        )
    )
    .frame(width: 320, height: 50)
}

#Preview("Compressed - Enabled Default Button") {
    BookmarkDialogButtonsView(
        viewState: .compressed,
        otherButtonAction: .init(
            title: "Left",
            action: { _ in }
        ),
        defaultButtonAction: .init(
            title: "Right",
            isDisabled: false,
            action: {_ in }
        )
    )
    .frame(width: 320, height: 50)
}

#Preview("Expanded - Disable Default Button") {
    BookmarkDialogButtonsView(
        viewState: .expanded,
        otherButtonAction: .init(
            title: "Left",
            action: { _ in }
        ),
        defaultButtonAction: .init(
            title: "Right",
            isDisabled: true,
            action: {_ in }
        )
    )
    .frame(width: 320, height: 50)
}

#Preview("Expanded - Enable Default Button") {
    BookmarkDialogButtonsView(
        viewState: .expanded,
        otherButtonAction: .init(
            title: "Left",
            action: { _ in }
        ),
        defaultButtonAction: .init(
            title: "Right",
            isDisabled: false,
            action: {_ in }
        )
    )
    .frame(width: 320, height: 50)
}
