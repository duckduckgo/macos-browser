//
//  DebugManagePurchasesViewController.swift
//  DuckDuckGo
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

public final class DebugManagePurchasesViewController: NSViewController {

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public init() {
//        manager = PurchaseManager.shared
//        model = PurchaseViewModel()
//        actions = PurchaseViewActions(manager: manager, model: model)

        super.init(nibName: nil, bundle: nil)
    }

    deinit {
        print(" -- PurchaseViewController deinit --")
    }

    public override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 650, height: 700))

//            let purchaseView = PurchaseView(manager: manager,
//                                            model: self.model,
//                                            actions: self.actions,
//                                            dismissAction: { [weak self] in
//                guard let self = self else { return }
//                self.presentingViewController?.dismiss(self)
//            })

//            view.addAndLayout(NSHostingView(rootView: purchaseView))
    }

    public override func viewDidAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.presentingViewController?.dismiss(self)
        }
    }
}
