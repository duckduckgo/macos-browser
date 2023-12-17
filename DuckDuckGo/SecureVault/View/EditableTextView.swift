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

    var isEditable: Bool
    var font: NSFont
    var onEditingChanged: () -> Void
    var onCommit: () -> Void
    var onTextChange: (String) -> Void
    var maxLength: Int?
    var insets: NSSize?

    init(text: Binding<String>, isEditable: Bool = true, font: NSFont?, onEditingChanged: @escaping () -> Void = {}, onCommit: @escaping () -> Void = {}, onTextChange: @escaping (String) -> Void = { _ in }, maxLength: Int? = nil, insets: NSSize? = nil) {

        self._text = text
        self.isEditable = isEditable
        self.font = font ?? .systemFont(ofSize: 13, weight: .regular)
        self.onEditingChanged = onEditingChanged
        self.onCommit = onCommit
        self.onTextChange = onTextChange
        self.maxLength = maxLength
        self.insets = insets
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    func makeNSView(context: Context) -> CustomTextView {
        let textView = CustomTextView(
            text: text,
            isEditable: isEditable,
            font: font,
            insets: insets,
            delegate: context.coordinator
        )
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
            guard let textView = notification.object as? NSTextView else { return }

            if let maxLength = parent.maxLength, textView.string.count > maxLength {
                textView.string = String(textView.string.prefix(maxLength))
            }

            if self.parent.text != textView.string {
                self.parent.text = textView.string
            }
            self.selectedRanges = textView.selectedRanges
        }

    }

}

// MARK: - CustomTextView

final class CustomTextView: NSView {

    weak var delegate: NSTextViewDelegate?

    var text: String {
        didSet {
            if textView.string != text {
                textView.string = text
            }
        }
    }

    var selectedRanges: [NSValue] = [] {
        didSet {
            guard !selectedRanges.isEmpty else { return }
            textView.selectedRanges = selectedRanges
        }
    }

    let scrollView: NSScrollView
    let textView: NSTextView

    // MARK: - Init

    init(text: String = "", isEditable: Bool, font: NSFont, insets: NSSize? = nil, delegate: NSTextViewDelegate? = nil, selectedRanges: [NSValue] = []) {

        self.text = text
        self.selectedRanges = selectedRanges

        self.delegate = delegate

        scrollView = NSScrollView()
        scrollView.drawsBackground = true
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalRuler = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: scrollView.frame.size)
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        layoutManager.addTextContainer(textContainer)

        textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.autoresizingMask = .width
        textView.backgroundColor = NSColor(named: "PWMEditingControlColor")!
        textView.delegate = self.delegate
        textView.drawsBackground = true
        textView.font = font
        textView.isEditable = isEditable
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.textColor = NSColor.labelColor
        textView.allowsUndo = true
        textView.string = text

        if let insets {
            textView.textContainerInset = insets
        }
        if !selectedRanges.isEmpty {
            textView.selectedRanges = selectedRanges
        }

        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
