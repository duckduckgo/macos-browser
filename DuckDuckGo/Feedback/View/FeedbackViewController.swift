//
//  FeedbackViewController.swift
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

import Cocoa
import Combine

final class FeedbackViewController: NSViewController {

    @IBOutlet weak var categoryPopUpButton: NSPopUpButton!
    @IBOutlet weak var pickCategoryMenuItem: NSMenuItem!
    @IBOutlet weak var brokenWebsiteMenuItem: NSMenuItem!

    @IBOutlet weak var contentView: ColorView!
    @IBOutlet weak var contentViewHeightContraint: NSLayoutConstraint!

    @IBOutlet weak var browserFeedbackView: NSView!
    @IBOutlet weak var textField: NSTextField!

    @IBOutlet weak var websiteBreakageView: NSView!
    @IBOutlet weak var subcategoryPopUpButton: NSPopUpButton!
    @IBOutlet weak var pickIssueMenuItem: NSMenuItem!
    @IBOutlet weak var submitButton: NSButton!

    private var cancellables = Set<AnyCancellable>()

    var currentTabContent: Tab.TabContent?

    private let feedbackSender = FeedbackSender()

    override func viewDidLoad() {
        super.viewDidLoad()
        textField.delegate = self
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(popUpButtonOpened(_:)),
                                               name: NSPopUpButton.willPopUpNotification,
                                               object: nil)
        updateBrokenWebsiteMenuItem()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()

        // swiftlint:disable notification_center_detachment
        NotificationCenter.default.removeObserver(self)
        // swiftlint:enable notification_center_detachment
    }

    @IBAction func categoryPopUpButton(_ sender: Any) {
        updateViews()
    }

    @IBAction func subcategoryPopUpButton(_ sender: Any) {
        updateViews()
    }

    @objc func popUpButtonOpened(_ notification: Notification) {
        guard let popUpButton = notification.object as? NSPopUpButton else {
            assertionFailure("No popup button")
            return
        }

        if popUpButton == categoryPopUpButton {
            pickCategoryMenuItem.isEnabled = false
        } else if popUpButton == subcategoryPopUpButton {
            pickIssueMenuItem.isEnabled = false
        } else {
            assertionFailure("Unknown popup button")
        }
    }

    @IBAction func submitButtonAction(_ sender: Any) {
        sendFeedback()

        guard let window = view.window,
              let sheetParent = window.sheetParent else {
                  assertionFailure("No sheet parent")
                  return
              }

        sheetParent.endSheet(window, returnCode: .OK)
    }

    @IBAction func cancelButtonAction(_ sender: Any) {
        guard let window = self.view.window,
              let sheetParent = window.sheetParent else {
                  assertionFailure("No sheet parent")
                  return
              }

        sheetParent.endSheet(window, returnCode: .cancel)
    }

    private var selectedCategory: Feedback.Category? {
        guard let categoryItem = categoryPopUpButton.selectedItem,
              categoryItem.tag >= 0,
              let category = Feedback.Category(tag: categoryItem.tag) else {
                  return nil
              }
        return category
    }

    private var selectedSubCategory: Feedback.Subcategory? {
        guard let subcategoryItem = subcategoryPopUpButton.selectedItem,
              let subcategory = Feedback.Subcategory(tag: subcategoryItem.tag) else {
                  return nil
              }
        return subcategory
    }

    private func updateViews() {
        defer {
            updateSubmitButton()
        }

        guard let selectedCategory = selectedCategory else {
            browserFeedbackView.isHidden = true
            websiteBreakageView.isHidden = true
            contentViewHeightContraint.constant = 160
            pickCategoryMenuItem.isEnabled = true
            return
        }

        let contentHeight: CGFloat
        switch selectedCategory {
        case .bug, .featureRequest, .other:
            browserFeedbackView.isHidden = false
            contentHeight = 338
            textField.makeMeFirstResponder()
        case .websiteBreakage:
            browserFeedbackView.isHidden = true
            contentHeight = 235
            if selectedSubCategory == nil {
                pickIssueMenuItem.isEnabled = true
            }
        }
        websiteBreakageView.isHidden = !browserFeedbackView.isHidden
        NSAnimationContext.runAnimationGroup { [weak self] context in
            context.duration = 1/3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self?.contentViewHeightContraint.animator().constant = contentHeight
        }
    }

    private func updateSubmitButton() {
        guard let selectedCategory = selectedCategory else {
            submitButton.isEnabled = false
            return
        }

        switch selectedCategory {
        case .featureRequest, .bug, .other:
            if !textField.stringValue.trimmingWhitespaces().isEmpty {
                submitButton.isEnabled = true
            } else {
                submitButton.isEnabled = false
            }
        case .websiteBreakage:
            if selectedSubCategory != nil {
                submitButton.isEnabled = true
            } else {
                submitButton.isEnabled = false
            }
        }

        submitButton.bezelColor = submitButton.isEnabled ? NSColor.controlAccentColor: nil
    }

    private func updateBrokenWebsiteMenuItem() {
        brokenWebsiteMenuItem.isEnabled = currentTabContent?.isUrl ?? false
    }

    private func sendFeedback() {
        guard let category = selectedCategory,
              let feedback = Feedback(category: category,
                                      subcategory: selectedSubCategory,
                                      comment: textField.stringValue == "" ? nil : textField.stringValue)
        else {
            assertionFailure("Can't send feedback")
            return
        }
        feedbackSender.sendFeedback(feedback,
                                    appVersion: "\(AppVersion.shared.versionNumber)",
                                    osVersion: "\(ProcessInfo.processInfo.operatingSystemVersion)")
    }
}

fileprivate extension Feedback.Category {

    init?(tag: Int) {
        switch tag {
        case 0: self = .websiteBreakage
        case 1: self = .bug
        case 2: self = .featureRequest
        case 3: self = .other
        default:
            return nil
        }

    }

}

fileprivate extension Feedback.Subcategory {

    init?(tag: Int) {
        switch tag {
        case 0: self = .theSiteAskedToDisable
        case 1: self = .cantSignIn
        case 2: self = .linksDontWork
        case 3: self = .imagesDidntLoad
        case 4: self = .videoDidntPlay
        case 5: self = .contentIsMissing
        case 6: self = .commentsDidntLoad
        case 7: self = .somethingElse

        default:
            return nil
        }
    }

}

extension FeedbackViewController: NSTextFieldDelegate {

    func controlTextDidChange(_ notification: Notification) {
        updateSubmitButton()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSStandardKeyBindingResponding.insertNewline(_:)) {
            textView.insertNewlineIgnoringFieldEditor(self)
            return true
        }
        return false
    }

}
