//
//  JSAlertController.swift
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
import Combine

final class JSAlertController: NSViewController {

    private enum Constants {
        static let storyboardName = "JSAlert"
        static let appearAnimationDuration = 0.05
        static let dismissAnimationDuration = 0.1
        static let scrollViewToTextfieldSpacing = 8.0
    }

    var appearanceCancellable: AnyCancellable?

    @IBOutlet var scrollViewHeight: NSLayoutConstraint!
    @IBOutlet var alertCenterYAlignment: NSLayoutConstraint!

    @IBOutlet var backgroundView: NSView!
    @IBOutlet var alertView: NSView!
    @IBOutlet var verticalStackView: NSStackView!
    @IBOutlet var titleText: NSTextField!
    @IBOutlet var scrollView: NSScrollView!
    @IBOutlet var messageText: NSTextView!
    @IBOutlet var textField: NSTextField!
    @IBOutlet var okButton: NSButton!
    @IBOutlet var cancelButton: NSButton!

    private let viewModel: JSAlertViewModel

    static func create(_ query: JSAlertQuery) -> JSAlertController {
        let instance = NSStoryboard(name: Constants.storyboardName, bundle: nil).instantiateInitialController { coder in
            return JSAlertController(query: query, coder: coder)
        }
        return instance!
    }

    init?(query: JSAlertQuery, coder: NSCoder) {
        self.viewModel = JSAlertViewModel(query: query)
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        appearanceCancellable = NSApp.publisher(for: \.effectiveAppearance).receive(on: DispatchQueue.main).sink { [weak self] _ in
            NSAppearance.withAppAppearance {
                self?.alertView.layer?.backgroundColor = NSColor.panelBackgroundColor.cgColor
            }
        }
        alertView.layer?.cornerRadius = 10.0
        alertView.applyDropShadow()
        backgroundView.layer?.backgroundColor = CGColor(gray: 0.0, alpha: 0.2)

        messageText.textContainer?.lineFragmentPadding = 0.0
        messageText.isEditable = false
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        presentData()
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        let messageHeight = messageText.textSize.height
        scrollViewHeight.constant = messageHeight

        if messageHeight <= scrollView.frame.height {
            scrollView.verticalScrollElasticity = .none
            scrollView.hasVerticalScroller = false
        } else {
            scrollView.verticalScrollElasticity = .automatic
            scrollView.hasVerticalScroller = true
        }

        guard let windowContentView = view.window?.contentView else {
            return
        }
        let windowCenter = CGPoint(x: windowContentView.frame.midX, y: windowContentView.frame.midY)
        let windowPoint = windowContentView.convert(windowCenter, to: view)
        let viewCenter = CGPoint(x: view.frame.midX, y: view.frame.midY)
        alertCenterYAlignment.constant = viewCenter.y - windowPoint.y
    }

    @IBAction func okAction(_ sender: NSButton) {
        dehighlightTextField()
        viewModel.confirm(text: textField.stringValue)
    }

    @IBAction func cancelAction(_ sender: Any?) {
        dehighlightTextField()
        viewModel.cancel()
    }

    override func cancelOperation(_ sender: Any?) {
        cancelAction(sender)
    }

    private func presentData() {
        okButton.title = viewModel.okButtonText
        cancelButton.title = viewModel.cancelButtonText
        titleText.stringValue = viewModel.titleText
        messageText.string = viewModel.messageText

        cancelButton.isHidden = viewModel.isCancelButtonHidden

        textField.isHidden = viewModel.isTextFieldHidden
        let scrollViewSpacing = viewModel.isTextFieldHidden ? verticalStackView.spacing : Constants.scrollViewToTextfieldSpacing
        verticalStackView.setCustomSpacing(scrollViewSpacing, after: scrollView)
        textField.stringValue = viewModel.textFieldDefaultText
        messageText.sizeToFit()
        scrollView.contentInsets = NSEdgeInsetsZero
    }
    
    private func dehighlightTextField() {
        view.window?.endEditing(for: nil)
        textField.focusRingType = .none // prevents dodgy animation out
    }
}

extension JSAlertController: NSViewControllerPresentationAnimator {
    func animatePresentation(of viewController: NSViewController, from fromViewController: NSViewController) {
        guard viewController === self else { return }
        fromViewController.addAndLayoutChild(self)
        setAlertAnchorPoint(anchorPoint: CGPoint(x: 0.5, y: 0.5))
        backgroundView.layer?.opacity = 0.0
        alertView.layer?.transform = CATransform3DMakeScale(0.95, 0.95, 1)
        alertView.layer?.opacity = 0.0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.animateIn { [weak self] in
                self?.textField.makeMeFirstResponder()
            }
        }
    }

    func animateDismissal(of viewController: NSViewController, from fromViewController: NSViewController) {
        guard viewController === self else { return }
        animateOut { [weak self] in
            self?.removeCompletely()
        }
    }

    private func animateIn(_ completion: @escaping () -> Void) {
        animate(
            transform: Animation(fromValue: CATransform3DMakeScale(0.95, 0.95, 1), toValue: CATransform3DIdentity),
            backgroundOpacity: Animation(fromValue: 0.0, toValue: 1.0),
            alertOpacity: Animation(fromValue: 0.75, toValue: 1.0),
            duration: Constants.appearAnimationDuration,
            completion: completion
        )
    }

    private func animateOut(_ completion: @escaping () -> Void) {
        animate(
            transform: Animation(fromValue: CATransform3DIdentity, toValue: CATransform3DMakeScale(0.95, 0.95, 1)),
            backgroundOpacity: Animation(fromValue: 1.0, toValue: 0.0),
            alertOpacity: Animation(fromValue: 1.0, toValue: 0.0),
            duration: Constants.dismissAnimationDuration,
            completion: completion
        )
    }

    private struct Animation<Value> {
        let fromValue: Value
        let toValue: Value
    }

    private func animate(
        transform: Animation<CATransform3D>,
        backgroundOpacity: Animation<Float>,
        alertOpacity: Animation<Float>,
        duration: CFTimeInterval,
        completion: @escaping () -> Void
    ) {
        let layer = alertView.layer!
        setAlertAnchorPoint(anchorPoint: CGPoint(x: 0.5, y: 0.5))
        CATransaction.setCompletionBlock(completion)

        CATransaction.begin()

        alertView.layer?.transform = transform.toValue
        alertView.layer?.opacity = alertOpacity.toValue
        backgroundView.layer?.opacity = backgroundOpacity.toValue

        let scaleAnimation = CABasicAnimation(keyPath: "transform")
        scaleAnimation.fromValue = transform.fromValue
        scaleAnimation.toValue = transform.toValue

        let alertOpacity = CABasicAnimation(keyPath: "opacity")
        alertOpacity.fromValue = alertOpacity.fromValue
        alertOpacity.toValue = alertOpacity.toValue

        let group = CAAnimationGroup()
        group.duration = duration
        group.timingFunction = CAMediaTimingFunction(name: .easeIn)
        group.animations = [scaleAnimation, alertOpacity]

        layer.add(group, forKey: "scaleAndOpacity")

        let backgroundOpacity = CABasicAnimation(keyPath: "opacity")
        backgroundOpacity.fromValue = backgroundOpacity.fromValue
        backgroundOpacity.toValue = backgroundOpacity.toValue

        backgroundView.layer?.add(backgroundOpacity, forKey: "opacity")

        CATransaction.commit()
    }

    private func setAlertAnchorPoint(anchorPoint: CGPoint) {
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
}
