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
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet var textView: NSTextView!
    @IBOutlet weak var subcategoryPopUpButton: NSPopUpButton!
    @IBOutlet weak var submitButton: NSButton!

    private var cancellables = Set<AnyCancellable>()

    var feedback: Feedback? {
        didSet {
            updateViews()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 10
        scrollView.contentView.wantsLayer = true
        scrollView.layer?.cornerRadius = 10
    }

    @IBAction func categoryPopUpButton(_ sender: Any) {
        updateFeedback()
    }

    @IBAction func subcategoryPopUpButton(_ sender: Any) {
        updateFeedback()
    }

    @IBAction func submitButtonAction(_ sender: Any) {
        updateFeedback()
        //TODO submit
        view.window?.close()
    }

    private func updateFeedback() {
        guard let categoryItem = categoryPopUpButton.selectedItem,
              let category = Feedback.Category(tag: categoryItem.tag) else {
                  feedback = nil
                  return
              }

        if !category.subcategories.isEmpty {
            guard let subcategoryItem = subcategoryPopUpButton.selectedItem,
                  let subcategory = Feedback.Subcategory(tag: subcategoryItem.tag) else {
                      feedback = nil
                      return
                  }

            feedback = Feedback(category: category, subcategory: subcategory, comment: nil)
        } else {
            feedback = Feedback(category: category, subcategory: nil, comment: textView.string)
        }
    }

    private func updateViews() {
        var isSubcategoryButtonHidden = true
        var isSubmitButtonEnabled = true
        var isTextViewEditable = true

        if let feedback = feedback {
            isSubcategoryButtonHidden = feedback.category != .websiteBreakage
        } else {
            if let categoryItem = categoryPopUpButton.selectedItem,
               let category = Feedback.Category(tag: categoryItem.tag) {
                if category == .websiteBreakage {
                    isSubcategoryButtonHidden = false
                    isSubmitButtonEnabled = false
                }
            } else {
                isSubmitButtonEnabled = false
                isTextViewEditable = false
            }
        }

        textView.isEditable = isTextViewEditable
        submitButton.isEnabled = isSubmitButtonEnabled
        subcategoryPopUpButton.isHidden = isSubcategoryButtonHidden
        scrollView.isHidden = !subcategoryPopUpButton.isHidden

        if !scrollView.isHidden {
            textView.makeMeFirstResponder()
        }
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
