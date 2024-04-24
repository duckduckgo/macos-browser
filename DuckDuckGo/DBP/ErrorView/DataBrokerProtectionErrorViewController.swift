//
//  DataBrokerProtectionErrorViewController.swift
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
import SwiftUI

final class DataBrokerProtectionErrorViewController: NSViewController {
    private var errorSubview: NSView?

    var errorViewModel: DataBrokerProtectionErrorViewModel? {
        didSet {
            guard let errorViewModel = errorViewModel else { return }

            errorSubview?.removeFromSuperview()

            let errorView = DataBrokerProtectionErrorView(viewModel: errorViewModel)
            errorSubview = NSHostingView(rootView: errorView)

            if let errorSubview = errorSubview {
                view.addAndLayout(errorSubview)
            }
        }
    }
}

struct DataBrokerProtectionErrorView: View {
    var viewModel: DataBrokerProtectionErrorViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 16) {

            HStack {
                Image("DaxLockScreenLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)

                Text("Privacy Pro")
                    .font(.title)
                    .fontWeight(.light)
            }
            .padding(.bottom, 25)

            HStack {
                Image("dbp-error-info")
                    .resizable()
                    .frame(width: 24, height: 24)

                Text(viewModel.title)
                    .font(.title)
                    .fontWeight(.light)
            }

            Text(viewModel.message)
                .font(.body)
                .fontWeight(.light)
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)

            Button(action: {
                viewModel.ctaAction()
            }) {
                Text(viewModel.ctaText)
            }

            Spacer()
        }.padding()
            .frame(maxWidth: 500)
    }
}

struct DataBrokerProtectionErrorViewModel {
    let title: String
    let message: String
    let ctaText: String
    let ctaAction: () -> Void
}
