//
//  SaveCredentialsView.swift
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

import SwiftUI
import BrowserServicesKit

final class SaveCredentialsModel: ObservableObject {

    @Published var domain: String
    @Published var username: String
    @Published var password: String
    @Published var fireproofWebsite: Bool = false

    init(credentials: SecureVaultModels.WebsiteCredentials) {
        domain = credentials.account.domain
        username = credentials.account.username
        password = String(data: credentials.password, encoding: .utf8) ?? ""
    }

}

struct SaveCredentialsView: View {

    @ObservedObject var model: SaveCredentialsModel
    @State var showPassword = false

    let titleFont = Font.system(size: 15, weight: .bold, design: .default)
    let domainFont = Font.system(size: 13, weight: .medium, design: .default)
    let labelFont = Font.system(size: 13, weight: .bold, design: .default)
    let buttonFont = Font.system(size: 13, weight: .regular, design: .default)
    let inputFont = Font.system(size: 13, weight: .regular, design: .default)

    var body: some View {

        VStack(alignment: .leading, spacing: 8) {
            Text("Save username and password?")
                .font(titleFont)
                .padding()

            Divider()

            VStack(alignment: .leading, spacing: 16) {

                HStack {
                    Image("Web")
                        .frame(width: 16, height: 16)

                    Text(model.domain)
                        .font(domainFont)
                }

                VStack(alignment: .leading) {
                    Text("Username")
                        .font(labelFont)
                    TextField("", text: $model.username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                VStack(alignment: .leading) {
                    Text("Password")
                        .font(labelFont)
                        .bold()
                    ZStack(alignment: .trailing) {
                        if showPassword {
                            TextField("", text: $model.password)
                                .font(inputFont)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        } else {
                            SecureField("", text: $model.password)
                                .font(inputFont)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }

                        Image("SecureEyeToggle").onTapGesture {
                            showPassword = !showPassword
                        }.padding(.trailing)
                    }
                }

                Toggle("Fireproof this website", isOn: $model.fireproofWebsite)

            }
            .toggleStyle(CheckboxToggleStyle())
            .padding(.horizontal)

            Divider()

            Spacer()

            HStack(alignment: .center) {

                Button(action: {}) {
                    Text("Never")
                        .frame(width: 80, height: 20)
                        .font(buttonFont)
                }

                Spacer()

                Button(action: {}) {
                    Text("Not Now")
                        .frame(width: 80, height: 20)
                        .font(buttonFont)
                }

                Button(action: {
                    print("save")
                }) {                    
                    EmptyView().frame(height: 1)
                    Text("Save")
                        .frame(width: 80, height: 20)
                        .font(buttonFont)
                }

            }.padding(.horizontal)

            Spacer()

        }
        .frame(minWidth: 400, idealWidth: 400)
        .background(Color.init("InterfaceBackgroundColor"))
    }

}
