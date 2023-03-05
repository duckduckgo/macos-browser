//
//  RecoverAccountView.swift
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

public protocol RecoverAccountViewModel: ObservableObject {
    associatedtype RecoverAccountViewUserText: SyncUI.RecoverAccountViewUserText

    func endFlow()
    func recoverDevice(using recoveryCode: String)
}

public protocol RecoverAccountViewUserText {
    static var recoverSyncedDataTitle: String { get }
    static var cancel: String { get }
    static var submit: String { get }
    static var syncNewDeviceEnterCodeInstructions: String { get }
    static var pasteFromClipboard: String { get }
}

public struct RecoverAccountView<ViewModel>: View where ViewModel: RecoverAccountViewModel {
    typealias UserText = ViewModel.RecoverAccountViewUserText

    @EnvironmentObject public var model: ViewModel
    @EnvironmentObject public var recoveryCodeModel: RecoveryCodeViewModel
//    @ObservedObject public var recoveryCodeModel = RecoveryCodeViewModel()

    public init() {}

    public var body: some View {
        SyncWizardStep(spacing: 20.0) {
            Text(UserText.recoverSyncedDataTitle)
                .font(.system(size: 17, weight: .bold))

            EnterCodeView<ViewModel>()
                .environmentObject(recoveryCodeModel)

        } buttons: {
            Button(UserText.cancel) {
                model.endFlow()
            }
            Button(UserText.submit) {
                model.recoverDevice(using: recoveryCodeModel.recoveryCode)
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: !recoveryCodeModel.shouldDisableSubmitButton))
            .disabled(recoveryCodeModel.shouldDisableSubmitButton)
        }
        .frame(width: 480, height: 432)
    }

}

private struct CopyPasteButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    let verticalPadding: CGFloat

    init(verticalPadding: CGFloat = 6.0) {
        self.verticalPadding = verticalPadding
    }

    func makeBody(configuration: Self.Configuration) -> some View {

        let color: Color = configuration.isPressed ? Color(NSColor.windowBackgroundColor) : Color(NSColor.controlColor)

        let outerShadowOpacity = colorScheme == .dark ? 0.8 : 0.0

        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(color)
                    .shadow(color: .black.opacity(0.1), radius: 0.1, x: 0, y: 1)
                    .shadow(color: .primary.opacity(outerShadowOpacity), radius: 0.1, x: 0, y: -0.6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
            )
    }
}

struct EnterCodeView<ViewModel>: View where ViewModel: RecoverAccountViewModel {
    typealias UserText = ViewModel.RecoverAccountViewUserText

    @EnvironmentObject var recoveryCodeModel: RecoveryCodeViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text(UserText.syncNewDeviceEnterCodeInstructions)
                .multilineTextAlignment(.center)

            SyncKeyView(text: recoveryCodeModel.recoveryCode)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .roundedBorder()
                .frame(maxWidth: 244)

            Button {
                recoveryCodeModel.recoveryCode = NSPasteboard.general.string(forType: .string) ?? ""
            } label: {
                HStack {
                    Image("Paste")
                    Text(UserText.pasteFromClipboard)
                }
            }
            .buttonStyle(CopyPasteButtonStyle(verticalPadding: 8.0))
        }
        .padding(20)
        .roundedBorder()
    }
}

struct SyncKeyView: View {
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(paddedText.prefix(64)).chunked(into: 16)) { rowChunk in
                HStack {
                    Text(String(rowChunk[0..<4]))
                        .font(monospaceFont)
                    Spacer()
                    Text(String(rowChunk[4..<8]))
                        .font(monospaceFont)
                    Spacer()
                    Text(String(rowChunk[8..<12]))
                        .font(monospaceFont)
                    Spacer()
                    Text(String(rowChunk[12..<16]))
                        .font(monospaceFont)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var paddedText: String {
        text.count > 64 ? String(text.prefix(63) + "…") : String(text.padding(toLength: 64, withPad: " ", startingAt: 0))
    }

    private var monospaceFont: Font {
        if #available(macOS 12.0, *) {
            return .system(size: 15, weight: .semibold).monospaced()
        }
        return Font.custom("SF Mono", size: 15).weight(.semibold)
    }
}

extension Array: Identifiable where Element == Character {
    public var id: String {
        UUID().uuidString
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
