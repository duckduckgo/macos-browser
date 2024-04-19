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
        VStack(alignment: .center, spacing: 9) {

            Text(viewModel.title)
                .font(.title2)

            Text(viewModel.message)
                .font(.body)
                .multilineTextAlignment(.center)

            Button(action: {
                viewModel.ctaAction()
            }) {
                Text(viewModel.ctaText)
            }
            Spacer()
        }.padding()
            .frame(maxWidth: 600)
    }
}

struct DataBrokerProtectionErrorViewModel {
    let title: String
    let message: String
    let ctaText: String
    let ctaAction: () -> Void
}
