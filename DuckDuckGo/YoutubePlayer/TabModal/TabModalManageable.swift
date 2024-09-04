//
//  TabModalManageable.swift
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

/// A protocol for handling the view controller to be displayed in the modal.
protocol TabModalPresentable: AnyObject {
    /// Initializes a new instance of the modal presenter with the given view controller.
    ///
    /// - Parameter modalViewController: The view controller to be presented in the modal.
    init(modalViewController: NSViewController)

    /// Closes the modal view controller.
    ///
    /// - Parameters:
    ///   - animated: A boolean indicating whether the closure of the modal should be animated.
    ///   - completion: An optional closure to be executed after the modal has been closed.
    func close(animated: Bool, completion: (() -> Void)?)

    /// Shows the modal view controller on the given view.
    ///
    /// - Parameters:
    ///   - currentTabView: The view on which the modal should be presented.
    ///   - animated: A boolean indicating whether the presentation of the modal should be animated.
    func show(on currentTabView: NSView, animated: Bool)
}

/// A protocol for managing the modal to be presented.
protocol TabModalManageable: AnyObject {
    associatedtype ModalType: TabModalPresentable

    var modal: ModalType? { get set }
    var viewController: NSViewController { get }

    /// Closes the modal view controller.
    ///
    /// - Parameters:
    ///   - animated: A boolean indicating whether the closure of the modal should be animated.
    ///   - completion: An optional closure to be executed after the modal has been closed.
    func close(animated: Bool, completion: (() -> Void)?)

    /// Shows the modal view controller on the given view.
    ///
    /// - Parameters:
    ///   - currentTabView: The view on which the modal should be presented.
    ///   - animated: A boolean indicating whether the presentation of the modal should be animated.
    func show(on currentTabView: NSView, animated: Bool)
}

extension TabModalManageable {

    func close(animated: Bool, completion: (() -> Void)?) {
        modal?.close(animated: animated) { [weak self] in
            self?.modal = nil
        }
    }

    func show(on currentTabView: NSView, animated: Bool) {
        prepareModal()
        modal?.show(on: currentTabView, animated: animated)
    }

    private func prepareModal() {
        guard modal == nil else { return }
        modal = ModalType(modalViewController: viewController)
    }
}
