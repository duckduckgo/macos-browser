//
//  DuckPlayerOnboardingModalManager.swift
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

protocol ModalPresentable: AnyObject {
    func close(animated: Bool, completion: (() -> Void)?)
    func show(on currentTabView: NSView, animated: Bool)
}

protocol TabModalViewControllerDelegate: AnyObject {
    var didFinish: () -> Void { get set }
}

protocol TabModalPresentable: AnyObject {
    associatedtype ModalType: TabModal

    var modal: ModalType? { get set }

    func show(on view: NSView, animated: Bool)
    func close(animated: Bool)
    func createModal() -> ModalType
}

extension TabModalPresentable {
    func show(on view: NSView, animated: Bool) {
        prepareModal()
        modal?.show(on: view, animated: animated)
    }

    func close(animated: Bool) {
        modal?.close(animated: animated) { [weak self] in
            self?.cleanUp()
        }
    }

    func cleanUp() {
        modal = nil
    }

    func prepareModal() {
        if modal == nil {
            modal = createModal()
        }
    }
}

final class DuckPlayerOnboardingModalManager: TabModalPresentable {
    typealias ModalType = TabModal

    var modal: TabModal?

    func createModal() -> TabModal {
        let viewController = DuckPlayerOnboardingViewController { [weak self] in
            self?.close(animated: true)
        }

        let modal = TabModal(modalViewController: viewController)
        return modal
    }
}
