//
//  DisposableHomePageView.swift
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

import Foundation
import SwiftUI

extension HomePage.Views {

    struct DisposableHomePageView: View {

        var body: some View {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color.white, Color(hex: "FFA235").opacity(0.3)]), startPoint: .top, endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 20) {
                    Image("DisposableWindowIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 76)

                    VStack(spacing: 20) {
                        Text(UserText.disposableWindowHeader)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(Color.primary)

                        Text(UserText.disposableWindowDescription)
                            .font(.system(size: 17))
                            .foregroundColor(Color.primary)
                            .lineSpacing(8)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .cornerRadius(20)
                    .padding(.vertical, 40)
                }
                .frame(width: 600, height: 600, alignment: .center)
            }
        }
    }
}
