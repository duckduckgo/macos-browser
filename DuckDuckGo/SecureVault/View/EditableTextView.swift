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

import AppKit
import Foundation
import SwiftUI

struct EditableTextView: NSViewRepresentable {

    var isEditable: Bool = true

    @Binding var text: String

    var font: NSFont = .systemFont(ofSize: 13, weight: .regular)
    var maxLength: Int?
    var insets: NSSize?
    var cornerRadius: CGFloat = 0
    var backgroundColor: NSColor? = .textEditorBackground
    var textColor: NSColor? = .textColor
    var focusRingType: NSFocusRingType = .default
    var isFocusedOnAppear: Bool = true

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    func makeNSView(context: Context) -> CustomTextView {
        let textView = CustomTextView(
            text: text,
            isEditable: isEditable,
            font: font,
            textColor: textColor,
            insets: insets,
            isFocusedOnAppear: isFocusedOnAppear,
            focusRingType: focusRingType,
            cornerRadius: cornerRadius,
            backgroundColor: backgroundColor,
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

    var text: String {
        didSet {
            guard textView.string != text else { return }
            textView.string = text
        }
    }

    var selectedRanges: [NSValue] = [] {
        didSet {
            guard !selectedRanges.isEmpty else { return }
            textView.selectedRanges = selectedRanges
        }
    }

    private let isFocusedOnAppear: Bool

    let scrollView: NSScrollView
    let textView: NSTextView

    // MARK: - Init

    init(text: String = "", isEditable: Bool, font: NSFont, textColor: NSColor? = nil, insets: NSSize? = nil, isFocusedOnAppear: Bool = false, focusRingType: NSFocusRingType = .default, cornerRadius: CGFloat = 0, backgroundColor: NSColor? = nil, delegate: NSTextViewDelegate? = nil, selectedRanges: [NSValue] = []) {

        self.text = text
        self.selectedRanges = selectedRanges
        self.isFocusedOnAppear = isFocusedOnAppear

        self.scrollView = RoundedCornersScrollView(cornerRadius: cornerRadius)

        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: .zero)
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        layoutManager.addTextContainer(textContainer)

        self.textView = NSTextView(frame: .zero, textContainer: textContainer)

        super.init(frame: .zero)

        setupScrollView(cornerRadius: cornerRadius, focusRingType: focusRingType, backgroundColor: backgroundColor)
        setupTextView(isEditable: isEditable, font: font, textColor: textColor, insets: insets, delegate: delegate)
        setupScrollViewConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("CustomTextView: Bad initializer")
    }

    private func setupScrollView(cornerRadius: CGFloat, focusRingType: NSFocusRingType, backgroundColor: NSColor?) {
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalRuler = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        if let backgroundColor {
            scrollView.drawsBackground = true
            scrollView.backgroundColor = backgroundColor
        } else {
            scrollView.drawsBackground = false
        }
        scrollView.focusRingType = focusRingType
        if cornerRadius > 0 {
            scrollView.wantsLayer = true
            scrollView.layer!.cornerRadius = cornerRadius
        }
    }

    private func setupTextView(isEditable: Bool, font: NSFont, textColor: NSColor?, insets: NSSize?, delegate: NSTextViewDelegate?) {
        textView.autoresizingMask = .width
        textView.delegate = delegate
        textView.drawsBackground = false
        textView.font = font
        textView.isEditable = isEditable
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.allowsUndo = true
        textView.string = text
        textView.wantsLayer = true

        if let textColor {
            textView.textColor = textColor
        }
        if let insets {
            textView.textContainerInset = insets
        }
        if !selectedRanges.isEmpty {
            textView.selectedRanges = selectedRanges
        }
    }

    private func setupScrollViewConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor)
        ])

        scrollView.documentView = textView
    }

    // MARK: - Life cycle

    override func viewDidMoveToWindow() {
        if isFocusedOnAppear, let window {
            window.makeFirstResponder(textView)
        }
    }
}

final class RoundedCornersScrollView: NSScrollView {

    let cornerRadius: CGFloat

    init(frame: NSRect = .zero, cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("RoudedCornersScrollView: Bad initializer")
    }

    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius).fill()
    }

}

#if DEBUG
extension EditableTextView {
    struct PreviewView: View {
        @State var text = """
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor)
        ])
        """

        var body: some View {
            VStack(spacing: 10) {
                EditableTextView(text: $text,
                                 font: .systemFont(ofSize: 18),
                                 insets: NSSize(width: 15, height: 10),
                                 cornerRadius: 15,
                                 backgroundColor: .textBackgroundColor,
                                 textColor: .purple,
                                 focusRingType: .exterior,
                                 isFocusedOnAppear: true)

                TextField("", text: .constant(""))
            }.padding(EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20))
        }

    }
}
#Preview {
    EditableTextView.PreviewView()
}
#endif
