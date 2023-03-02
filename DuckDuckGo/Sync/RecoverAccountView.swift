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

struct RecoverAccountView: View {
    @EnvironmentObject var model: SyncPreferences

    var body: some View {
        SyncWizardStep(spacing: 20.0) {
            Text(UserText.recoverSyncedDataTitle)
                .font(.system(size: 17, weight: .bold))

            EnterCodeView().environmentObject(model)

        } buttons: {
            Button(UserText.cancel) {
                model.endFlow()
            }
            Button(UserText.submit) {
                model.recoverDevice()
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: !model.shouldDisableSubmitButton))
            .disabled(model.shouldDisableSubmitButton)
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

private struct EnterCodeView: View {
    @EnvironmentObject var model: SyncPreferences

    var body: some View {
        Outline {
            VStack(spacing: 20) {
                Text(UserText.syncNewDeviceEnterCodeInstructions)
                    .multilineTextAlignment(.center)

                Outline {
                    SyncKeyView(text: model.recoveryKey)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .frame(maxWidth: 244)

                Button {
                    model.recoveryKey = NSPasteboard.general.string(forType: .string) ?? ""
                } label: {
                    HStack {
                        Image("Paste")
                        Text(UserText.pasteFromClipboard)
                    }
                }
                .buttonStyle(CopyPasteButtonStyle(verticalPadding: 8.0))
            }
            .padding(20)
        }
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
