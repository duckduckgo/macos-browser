//
//  DataBrokerRunCustomJSONViewController.swift
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

public final class DataBrokerRunCustomJSONViewController: NSViewController {
    private let authenticationManager: DataBrokerProtectionAuthenticationManaging

    public init(authenticationManager: DataBrokerProtectionAuthenticationManaging) {
        self.authenticationManager = authenticationManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        let contentView = DataBrokerRunCustomJSONView(viewModel: DataBrokerRunCustomJSONViewModel(authenticationManager: authenticationManager))
        let hostingController = NSHostingController(rootView: contentView)
        hostingController.view.autoresizingMask = [.width, .height]
        self.view = hostingController.view
    }
}
