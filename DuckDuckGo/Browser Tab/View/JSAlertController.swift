//
//  JSAlertController.swift
//  DuckDuckGo
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

final class JSAlertController: NSViewController {

    private enum Constants {
        static let appearAnimationDuration = 0.2
        static let dismissAnimationDuration = 0.3
        static let storyboardName = "JSAlert"
    }

    @IBOutlet var scrollViewHeight: NSLayoutConstraint!

    @IBOutlet var backgroundView: NSView!
    @IBOutlet var alertView: NSView!
    @IBOutlet var verticalStackView: NSStackView!
    @IBOutlet var titleText: NSTextField!
    @IBOutlet var scrollView: NSScrollView!
    @IBOutlet var messageText: NSTextView!
    @IBOutlet var textField: NSTextField!
    @IBOutlet var blockingCheckbox: NSButton!
    @IBOutlet var okButton: NSButton!
    @IBOutlet var cancelButton: NSButton!

    let viewModel: JSAlertViewModel

    private var isBlockingCheckboxOn: Bool {
        return blockingCheckbox.state == .on
    }

    static func create(_ viewModel: JSAlertViewModel) -> JSAlertController {
        let instance = NSStoryboard(name: Constants.storyboardName, bundle: nil).instantiateInitialController { coder in
            return JSAlertController(viewModel: viewModel, coder: coder)
        }
        return instance!
    }

    init?(viewModel: JSAlertViewModel, coder: NSCoder) {
        self.viewModel = viewModel
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        presentData()

        NSAppearance.withAppAppearance {
            alertView.layer?.backgroundColor = NSColor.backgroundSecondaryColor.cgColor
        }
        alertView.layer?.cornerRadius = 10.0
        alertView.applyDropShadow()
        backgroundView.layer?.backgroundColor = CGColor(gray: 0.0, alpha: 0.2)
        print("Scroll text inset: \(messageText.textContainerInset)")
        messageText.textContainer?.lineFragmentPadding = 0.0
        messageText.font = .systemFont(ofSize: 13)

        verticalStackView.setCustomSpacing(14.0, after: blockingCheckbox)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // hide container view

        alertView.alphaValue = 1.0
        backgroundView.alphaValue = 1.0

        // prevents initial layout bleeding into animation
        DispatchQueue.main.async { [weak self] in
            self?.animateIn { [weak self] in
                self?.textField.makeMeFirstResponder()
            }
        }
    }

    func animateIn(_ completion: @escaping () -> Void) {
        let layer = alertView.layer!
        setAlertAnchorPoint(anchorPoint: CGPoint(x: 0.5, y: 0.5))
        CATransaction.setCompletionBlock(completion)

        CATransaction.begin()

        alertView.layer?.transform = CATransform3DIdentity
        alertView.layer?.opacity = 1.0
        backgroundView.layer?.opacity = 1.0

        let scaleAnimation = CABasicAnimation(keyPath: "transform")
        scaleAnimation.fromValue = CATransform3DMakeScale(0.9, 0.9, 1)
        scaleAnimation.toValue = CATransform3DIdentity

        let alertOpacity = CABasicAnimation(keyPath: "opacity")
        alertOpacity.fromValue = 0.75
        alertOpacity.toValue = 1.0

        let group = CAAnimationGroup()
        group.duration = 0.2
        group.timingFunction = CAMediaTimingFunction(name: .easeIn)
        group.animations = [scaleAnimation, alertOpacity]

        layer.add(group, forKey: "scaleAndOpacity")

        let backgroundOpacity = CABasicAnimation(keyPath: "opacity")
        backgroundOpacity.fromValue = 0.0
        backgroundOpacity.toValue = 1.0

        backgroundView.layer?.add(backgroundOpacity, forKey: "opacity")

        CATransaction.commit()
    }

    func setAlertAnchorPoint(anchorPoint: CGPoint) {
        let initialNP = CGPoint(
            x: alertView.bounds.size.width * anchorPoint.x,
            y: alertView.bounds.size.height * anchorPoint.y
        )
        let initialOP = CGPoint(
            x: alertView.bounds.size.width * alertView.layer!.anchorPoint.x,
            y: alertView.bounds.size.height * alertView.layer!.anchorPoint.y
        )

        let newPoint = initialNP.applying(CATransform3DGetAffineTransform(alertView.layer!.transform))
        let oldPoint = initialOP.applying(CATransform3DGetAffineTransform(alertView.layer!.transform))

        var position = alertView.layer!.position

        position.x -= oldPoint.x
        position.x += newPoint.x

        position.y -= oldPoint.y
        position.y += newPoint.y

        alertView.layer!.position = position
        alertView.layer!.anchorPoint = anchorPoint
    }

    func dismiss(_ completion: @escaping () -> Void) {
        animateOut {
            completion()
        }
    }

    private func animateOut(_ completion: @escaping () -> Void) {
        CATransaction.setCompletionBlock(completion)
        let layer = alertView.layer!
        layer.removeAllAnimations()

        CATransaction.begin()
        alertView.layer?.transform = CATransform3DMakeScale(0.9, 0.9, 1)
        alertView.layer?.opacity = 0.0
        backgroundView.layer?.opacity = 0.0

        let scaleAnimation = CABasicAnimation(keyPath: "transform")
        scaleAnimation.fromValue = CATransform3DIdentity
        scaleAnimation.toValue = CATransform3DMakeScale(0.9, 0.9, 1)

        let alphaAnimation = CABasicAnimation(keyPath: "opacity")
        alphaAnimation.fromValue = 1.0
        alphaAnimation.toValue = 0.0

        let group = CAAnimationGroup()
        group.duration = 0.2
        group.timingFunction = CAMediaTimingFunction(name: .easeIn)
        group.animations = [scaleAnimation, alphaAnimation]

        layer.add(group, forKey: "scaleAndAlpha")

        let backgroundOpacity = CABasicAnimation(keyPath: "opacity")
        backgroundOpacity.fromValue = 1.0
        backgroundOpacity.toValue = 0.0

        backgroundView.layer?.add(backgroundOpacity, forKey: "opacity")

        CATransaction.commit()
    }

    private func presentData() {
        okButton.title = viewModel.okButtonText
        cancelButton.title = viewModel.cancelButtonText
        titleText.stringValue = viewModel.titleText
        messageText.string = viewModel.messageText

        cancelButton.isHidden = viewModel.isCancelButtonHidden
        messageText.sizeToFit()
        scrollViewHeight.constant = messageText.textSize.height + 4

        textField.isHidden = viewModel.isTextFieldHidden
        blockingCheckbox.isHidden = viewModel.isBlockingCheckboxHidden
        let scrollViewSpacing = viewModel.isTextFieldHidden ? verticalStackView.spacing : 4
        verticalStackView.setCustomSpacing(scrollViewSpacing, after: scrollView)
        textField.stringValue = viewModel.textFieldDefaultText
        blockingCheckbox.title = viewModel.checkboxText
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        if messageText.textSize.height <= scrollView.frame.height {
            scrollView.verticalScrollElasticity = .none
        } else {
            scrollView.verticalScrollElasticity = .automatic
        }
    }

    @IBAction func okAction(_ sender: NSButton) {
        view.window?.endEditing(for: nil)
        viewModel.confirm(text: textField.stringValue, shouldBlockAlerts: isBlockingCheckboxOn)
    }

    @IBAction func cancelAction(_ sender: NSButton) {
        view.window?.endEditing(for: nil)
        viewModel.cancel()
    }
}

final class JSAlertViewModel {
    private let query: JSAlertQuery

    init(query: JSAlertQuery) {
        self.query = query
    }

    var isCancelButtonHidden: Bool {
        switch query {
        case .alert:
            return true
        case .confirm, .textInput:
            return false
        }
    }

    var isTextFieldHidden: Bool {
        switch query {
        case .alert, .confirm:
            return true
        case .textInput:
            return false
        }
    }

    var isBlockingCheckboxHidden: Bool {
        return !query.parameters.hasDomainShownAlert
    }

    var okButtonText: String {
        "OK"
    }

    var cancelButtonText: String {
        "Cancel"
    }

    var checkboxText: String {
        "Suppress additional alerts until you reload the page"
    }

    var titleText: String {
        "A message from \(query.parameters.domain):"
    }

    var messageText: String {
        query.parameters.prompt
    }

    var textFieldDefaultText: String {
        query.parameters.defaultInputText ?? ""
    }

    func confirm(text: String, shouldBlockAlerts: Bool) {
        switch query {
        case .alert(let request):
            request.submit(.init(shouldBlockNext: shouldBlockAlerts))
        case .confirm(let request):
            request.submit(.init(completionArgument: true, shouldBlockNext: shouldBlockAlerts))
        case .textInput(let request):
            request.submit(.init(completionArgument: text, shouldBlockNext: shouldBlockAlerts))
        }
    }

    func cancel() {
        query.cancel()
    }
}

extension JSAlertQuery {
    var parameters: JSAlertParameters {
        switch self {
        case .alert(let request):
            return request.parameters
        case .confirm(let request):
            return request.parameters
        case .textInput(let request):
            return request.parameters
        }
    }

    func cancel() {
        switch self {
        case .alert(let request):
            return request.submit(.init(shouldBlockNext: false))
        case .confirm(let request):
            return request.submit(.init(completionArgument: false, shouldBlockNext: false))
        case .textInput(let request):
            return request.submit(.init(completionArgument: nil, shouldBlockNext: false))
        }
    }
}
