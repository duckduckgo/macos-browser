//
//  PasswordManagementItemView.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import SwiftUI
import BrowserServicesKit

private let interItemSpacing: CGFloat = 16
private let itemSpacing: CGFloat = 10

struct PasswordManagementItemView: View {

    @EnvironmentObject var model: PasswordManagementItemModel

    var body: some View {

        if model.credentials != nil {

            let editMode = model.isEditing || model.isNew

            ZStack(alignment: .top) {
                Spacer()

                if editMode {

                    RoundedRectangle(cornerRadius: 8)
                        .foregroundColor(Color(NSColor.editingPanelColor))
                        .shadow(radius: 6)

                }

                VStack(alignment: .leading, spacing: 0) {

                    HeaderView()
                        .padding(.bottom, editMode ? 20 : 30)

                    if model.isEditing || model.isNew {
                        Divider()
                            .padding(.bottom, 10)

                        LoginTitleView()
                    }

                    if model.twoFactorSecret.isEmpty {
                        Button(action: {
                            model.presentTwoFactorSecretWindow()
                        }) {
                            Text("Scan Two-Factor QR Code 􀖂")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .padding([.top, .bottom], 10)
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(PlainButtonStyle())
                        .background(Color.accentColor)
                        .cornerRadius(6)
                        .padding([.bottom], 25)
                    }

                    UsernameView()

                    PasswordView()

                    if !model.twoFactorSecret.isEmpty && !model.isEditing {
                        OneTimePasswordView()
                    } else if model.isEditing {
                        EditOneTimePasswordView()
                    }

                    WebsiteView()

                    if !model.isEditing && !model.isNew {
                        DatesView()
                    }

                    Spacer(minLength: 0)

                    Buttons()

                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("Got2FA"))) { notification in
                    guard let secret = notification.userInfo?["secret"] as? String else {
                        return
                    }

                    model.save(twoFactorSecret: secret)
                }

            }
            .padding(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 10))
        }

    }

}

private struct Buttons: View {

    @EnvironmentObject var model: PasswordManagementItemModel

    var body: some View {
        HStack {

            if model.isEditing && !model.isNew {
                Button(UserText.pmDelete) {
                    model.requestDelete()
                }
            }

            Spacer()

            if model.isEditing || model.isNew {
                Button("Remove 2FA") {
                    model.requestTwoFactorSecretDeletion()
                }

                Button(UserText.pmCancel) {
                    model.cancel()
                }

                if #available(macOS 11, *) {
                    Button(UserText.pmSave) {
                        model.save()
                    }
                    .keyboardShortcut(.defaultAction) // macOS 11+
                    .disabled(!model.isDirty)
                } else {
                    Button(UserText.pmSave) {
                        model.save()
                    }
                    .disabled(!model.isDirty)
                }

            } else {
                Button(UserText.pmDelete) {
                    model.requestDelete()
                }

                Button(UserText.pmEdit) {
                    model.edit()
                }
            }

        }.padding()
    }

}

private struct LoginTitleView: View {

    @EnvironmentObject var model: PasswordManagementItemModel

    var body: some View {

        Text(UserText.pmLoginTitle)
            .bold()
            .padding(.bottom, itemSpacing)

        TextField("", text: $model.title)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.bottom, interItemSpacing)

    }

}

private struct UsernameView: View {

    @EnvironmentObject var model: PasswordManagementItemModel

    @State var isHovering = false

    var body: some View {
        Text(UserText.pmUsername)
            .bold()
            .padding(.bottom, itemSpacing)

        if model.isEditing || model.isNew {

            TextField("", text: $model.username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.bottom, interItemSpacing)

        } else {

            HStack(spacing: 6) {
                Text(model.username)

                if isHovering {
                    Button {
                        model.copyUsername()
                    } label: {
                        Image("Copy")
                    }.buttonStyle(PlainButtonStyle())
                }
            }
            .onHover {
                isHovering = $0
            }
            .padding(.bottom, interItemSpacing)

        }

    }

}

private struct PasswordView: View {

    @EnvironmentObject var model: PasswordManagementItemModel

    @State var isHovering = false
    @State var isPasswordVisible = false

    var body: some View {
        Text(UserText.pmPassword)
            .bold()
            .padding(.bottom, itemSpacing)

        if model.isEditing || model.isNew {

            HStack {

                if isPasswordVisible {

                    TextField("", text: $model.password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                } else {

                    SecureField("", text: $model.password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                }

                Button {
                    isPasswordVisible = !isPasswordVisible
                } label: {
                    Image("SecureEyeToggle")
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 10)

            }
            .padding(.bottom, interItemSpacing)

        } else {

            HStack(alignment: .center, spacing: 6) {

                if isPasswordVisible {
                    Text(model.password)
                } else {
                    Text(model.password.isEmpty ? "" : "••••••••••••")
                }

                if isHovering || isPasswordVisible {
                    Button {
                        isPasswordVisible = !isPasswordVisible
                    } label: {
                        Image("SecureEyeToggle")
                    }.buttonStyle(PlainButtonStyle())
                }

                if isHovering {
                    Button {
                        model.copyPassword()
                    } label: {
                        Image("Copy")
                    }.buttonStyle(PlainButtonStyle())
                }
            }
            .onHover {
                isHovering = $0
            }
            .padding(.bottom, interItemSpacing)

        }
    }

}

struct CircularProgressView: View {
    @Binding var progress: Float

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 3.0)
                .opacity(0.3)
                .foregroundColor(Color.gray)

            Circle()
                .trim(from: 0.0, to: CGFloat(min(1.0 - self.progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 3.0, lineCap: .round, lineJoin: .round))
                .foregroundColor((1.0 - self.progress) > 0.25 ? Color.green : Color.red)
                .rotationEffect(Angle(degrees: 270.0))
        }
    }
}

private struct OneTimePasswordView: View {

    @EnvironmentObject var model: PasswordManagementItemModel

    @State var progressValue: Float = OneTimePasswordTimer.shared.percentComplete
    @State var secondsRemaining: TimeInterval = OneTimePasswordTimer.shared.remainder
    @State var isHovering = false

    private let formatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.second]
        return f
    }()

    var body: some View {
        Text(UserText.pmOneTimePassword)
            .bold()
            .padding(.bottom, itemSpacing)

        HStack(spacing: 6) {
            // The OTP should be cached somewhere and only change when the timer resets
            Text(TwoFactorCodeDetector.calculateSixDigitCode(secret: model.twoFactorSecret, date: Date())).font(.system(.body, design: .monospaced))

            if isHovering {
                Button {
                    model.copyOTP()
                } label: {
                    Image("Copy")
                }.buttonStyle(PlainButtonStyle())
            }

            Spacer()

            HStack {
                CircularProgressView(progress: $progressValue)
                    .frame(width: 12, height: 12, alignment: .leading)

                Text(formatter.string(from: secondsRemaining)!).font(.system(.body, design: .monospaced))
                    .fixedSize(horizontal: true, vertical: true)
            }
            .padding(6)
        }
        .onHover {
            isHovering = $0
        }
        .onReceive(NotificationCenter.default.publisher(for: OneTimePasswordTimer.timerProgressedNotification)) { notification in
            guard let remaining = notification.userInfo?[OneTimePasswordTimer.userInfoTimeRemainingKey] as? TimeInterval,
                  let percentComplete = notification.userInfo?[OneTimePasswordTimer.userInfoProgressKey] as? Float else {
                return
            }

            self.secondsRemaining = remaining
            self.progressValue = percentComplete
        }
        .padding(.bottom, interItemSpacing)

    }

}

private struct EditOneTimePasswordView: View {

    @EnvironmentObject var model: PasswordManagementItemModel

    var body: some View {

        Text(UserText.pmOneTimePassword)
            .bold()
            .padding(.bottom, itemSpacing)

        TextField("", text: $model.twoFactorSecret)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.bottom, interItemSpacing)

    }

}

private struct WebsiteView: View {

    @EnvironmentObject var model: PasswordManagementItemModel

    var body: some View {

        Text(UserText.pmWebsite)
            .bold()
            .padding(.bottom, itemSpacing)

        if model.isEditing || model.isNew {

            TextField("", text: $model.domain)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.bottom, interItemSpacing)

        } else {

            Text(model.domain)
                .padding(.bottom, interItemSpacing)

        }

    }

}

private struct DatesView: View {

    @EnvironmentObject var model: PasswordManagementItemModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(UserText.pmLoginAdded)
                    .bold()
                    .opacity(0.5)
                Text(model.createdDate)
                    .opacity(0.5)
            }

            HStack {
                Text(UserText.pmLoginLastUpdated)
                    .bold()
                    .opacity(0.5)
                Text(model.lastUpdatedDate)
                    .opacity(0.5)
            }
        }
    }

}

private struct HeaderView: View {

    @EnvironmentObject var model: PasswordManagementItemModel

    var body: some View {

        HStack(alignment: .center, spacing: 0) {

            FaviconView(domain: model.domain)
                .padding(.trailing, 10)

            if model.isNew {

                Text(UserText.pmNewLogin)
                    .font(.title)
                    .padding(.trailing, 4)

            } else {

                if model.isEditing {

                    Text(UserText.pmEdit)
                        .font(.title)
                        .padding(.trailing, 4)

                }

                Text(model.title.isEmpty ? model.domain.dropWWW() : model.title)
                    .font(.title)

            }

        }

    }

}
