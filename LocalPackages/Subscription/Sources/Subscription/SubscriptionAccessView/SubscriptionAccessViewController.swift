//
//  SubscriptionAccessViewController.swift
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

import AppKit
import SwiftUI

public final class SubscriptionAccessViewController: NSViewController {

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public init() {
        super.init(nibName: nil, bundle: nil)
    }

    public override func loadView() {
        let actionHandlers = SubscriptionAccessActionHandlers(
            restorePurchases: {
                // restore purchases
            },
            openURLHandler: { _ in
                // open URL here
            }, goToSyncPreferences: {
                // go to sync
            })

        // TODO: Support SubscriptionAccessModel states for the VC presentation
        let model = ActivateSubscriptionAccessModel(actionHandlers: actionHandlers)
//        let model = ShareSubscriptionAccessModel(actionHandlers: actionHandlers)


        let subscriptionAccessView = SubscriptionAccessView(model: model,
                                                            dismiss: { [weak self] in
                guard let self = self else { return }
                self.presentingViewController?.dismiss(self)
        })

        let hostingView = NSHostingView(rootView: subscriptionAccessView)
        let size = hostingView.fittingSize

        view = NSView(frame: NSRect(x: 0, y: 0, width: size.width, height: size.height))
        hostingView.frame = view.bounds
        hostingView.autoresizingMask = [.height, .width]
        hostingView.translatesAutoresizingMaskIntoConstraints = true

        view.addSubview(hostingView)
    }

}
