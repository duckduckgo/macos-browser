//
//  EditableTextView.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

struct EditableTextView: NSViewRepresentable {

    @Binding var text: String

    var isEditable: Bool = true
    var font: NSFont? = .systemFont(ofSize: 14, weight: .regular)
    var onEditingChanged: () -> Void       = {}
    var onCommit: () -> Void = {}
    var onTextChange: (String) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> CustomTextView {
        let textView = CustomTextView(
            text: text,
            isEditable: isEditable,
            font: font
        )
        textView.delegate = context.coordinator
        return textView
    }

    func updateNSView(_ view: CustomTextView, context: Context) {
        view.text = text
        view.selectedRanges = context.coordinator.selectedRanges
    }

}

extension EditableTextView {

    final class Coordinator: NSObject, NSTextViewDelegate {

        var parent: EditableTextView
        var selectedRanges: [NSValue] = []

        init(_ parent: EditableTextView) {
            self.parent = parent
        }

        func textDidBeginEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            self.parent.text = textView.string
            self.parent.onEditingChanged()
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            self.parent.text = textView.string
            self.selectedRanges = textView.selectedRanges
        }

    }

}

// MARK: - CustomTextView

final class CustomTextView: NSView {

    private var isEditable: Bool
    private var font: NSFont?
    weak var delegate: NSTextViewDelegate?

    var text: String {
        didSet {
            textView.string = text
        }
    }

    var selectedRanges: [NSValue] = [] {
        didSet {
            guard selectedRanges.count > 0 else {
                return
            }

            textView.selectedRanges = selectedRanges
        }
    }

    private lazy var scrollView: NSScrollView = {
        let scrollView = NSScrollView()

        scrollView.drawsBackground = true
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalRuler = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        return scrollView
    }()

    private lazy var textView: NSTextView = {
        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: scrollView.frame.size)
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        layoutManager.addTextContainer(textContainer)

        let textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.autoresizingMask = .width
        textView.backgroundColor = NSColor(named: "PWMEditingControlColor")!
        textView.delegate = self.delegate
        textView.drawsBackground = true
        textView.font = self.font
        textView.isEditable = self.isEditable
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.textColor = NSColor.labelColor
        textView.allowsUndo = true

        return textView
    }()

    // MARK: - Init

    init(text: String, isEditable: Bool, font: NSFont?) {
        self.font = font
        self.isEditable = isEditable
        self.text = text

        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    // MARK: - Life cycle

    override func viewWillDraw() {
        super.viewWillDraw()
        setupScrollViewConstraints()
        setupTextView()
    }

    func setupScrollViewConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor)
        ])
    }

    func setupTextView() {
        scrollView.documentView = textView
    }
}
