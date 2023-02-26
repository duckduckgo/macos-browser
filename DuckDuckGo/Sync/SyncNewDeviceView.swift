//
//  SyncNewDeviceView.swift
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
import EFQRCode

struct SyncNewDeviceView: View {
    @EnvironmentObject var model: SyncSetupViewModel

    enum Mode: Hashable {
        case showCode, enterCode
    }

    @State var selectedMode: Mode = .showCode

    var body: some View {
        SyncWizardStep(spacing: 20.0) {
            Text(UserText.syncNewDevice)
                .font(.system(size: 17, weight: .bold))

            Picker("", selection: $selectedMode) {
                Text(UserText.showCode).tag(Mode.showCode)
                Text(UserText.enterCode).tag(Mode.enterCode)
            }
            .pickerStyle(.segmented)

            switch selectedMode {
            case .showCode:
                ShowCodeView().environmentObject(model.preferences)
            case .enterCode:
                EnterCodeView().environmentObject(model.preferences)
            }
        } buttons: {
            switch selectedMode {
            case .showCode:
                Button(UserText.cancel) {
                    model.onCancel()
                }
            case .enterCode:
                Button(UserText.cancel) {
                    model.onCancel()
                }
                Button(UserText.submit) {
                    print("submit")
                }
                .buttonStyle(.borderedProminent)
            }
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

        let color = configuration.isPressed ? Color(nsColor: NSColor.windowBackgroundColor) : Color(nsColor: NSColor.controlColor)

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

private struct ShowCodeView: View {
    @EnvironmentObject var model: SyncPreferences

    var body: some View {
        Outline {
            VStack(spacing: 20) {
                Text(UserText.syncNewDeviceShowCodeInstructions)
                    .multilineTextAlignment(.center)

                HStack(alignment: .top, spacing: 20) {
                    if let image = EFQRCode.generate(for: model.syncKey, size: .init(width: 164, height: 164), backgroundColor: .clear, foregroundColor: NSColor(named: "BlackWhite100")!.cgColor) {
                        Image(nsImage: .init(cgImage: image, size: .init(width: 164, height: 164)))
                    } else {
                        EmptyView()
                            .frame(width: 192, height: 192)
                    }

                    VStack {
                        SyncKeyView(text: model.syncKey)

                        Spacer()

                        HStack {
                            Spacer()
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(model.syncKey, forType: .string)
                            } label: {
                                HStack {
                                    Image("Copy")
                                    Text(UserText.copy)
                                }
                            }
                            .buttonStyle(CopyPasteButtonStyle())
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .padding(20)
        }
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
                    SyncKeyView(text: model.syncKey)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .frame(maxWidth: 244)

                Button {
                    if let string = NSPasteboard.general.string(forType: .string) {
                        model.syncKey = string
                    }
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
                        .font(.system(size: 15, weight: .semibold).monospaced())
                    Spacer()
                    Text(String(rowChunk[4..<8]))
                        .font(.system(size: 15, weight: .semibold).monospaced())
                    Spacer()
                    Text(String(rowChunk[8..<12]))
                        .font(.system(size: 15, weight: .semibold).monospaced())
                    Spacer()
                    Text(String(rowChunk[12..<16]))
                        .font(.system(size: 15, weight: .semibold).monospaced())
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var paddedText: String {
        text.count > 64 ? String(text.prefix(63) + "…") : String(text.padding(toLength: 64, withPad: " ", startingAt: 0))
    }
}

extension Array: Identifiable where Element == Character {
    public var id: String {
        String(self)
    }
}
