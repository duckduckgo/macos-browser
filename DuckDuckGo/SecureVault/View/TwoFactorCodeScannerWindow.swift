//
//  TwoFactorCodeScannerWindow.swift
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

final class TwoFactorCodeScannerWindow {

    lazy var windowController: NSWindowController = {
        let storyboard = NSStoryboard(name: "SecureVault", bundle: nil)
        return storyboard.instantiateController(identifier: "TwoFactorCodeScannerWindowController")
    }()

    var viewController: TwoFactorCodeScannerViewController {
        // swiftlint:disable force_cast
        return windowController.contentViewController as! TwoFactorCodeScannerViewController
        // swiftlint:enable force_cast
    }

    func showScanner() {
        windowController.window?.backgroundColor = .clear
        windowController.showWindow(self)
        windowController.window?.center()
    }

}

final class TwoFactorCodeScannerViewController: NSViewController {

    @IBOutlet var overlayView: ColorView!
    @IBOutlet var maskView: NSView!

    override func viewDidLoad() {
        super.viewDidLoad()

        overlayView.wantsLayer = true

        let path = NSBezierPath(rect: overlayView.bounds)
        let transparentPath = NSBezierPath(roundedRect: CGRect(x: 66, y: 85, width: 268, height: 268), xRadius: 37, yRadius: 37)
        path.append(transparentPath)
        path.windingRule = .evenOdd

        let maskLayer = CAShapeLayer()
        maskLayer.fillColor = NSColor.black.withAlphaComponent(0.5).cgColor
        maskLayer.path = path.cgPath
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        maskLayer.backgroundColor = NSColor.clear.cgColor
        // overlayView.layer?.addSublayer(maskLayer)
        overlayView.layer = maskLayer
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        self.view.window?.titleVisibility = .hidden
        self.view.window?.titlebarAppearsTransparent = true
        self.view.window?.standardWindowButton(.zoomButton)?.isHidden = true
        self.view.window?.standardWindowButton(.closeButton)?.isHidden = false
        self.view.window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.view.window?.styleMask = [.closable, .titled, .fullSizeContentView]
    }

    @IBAction func scanWindow(_ sender: AnyObject) {
        // This isn't reliable in any way, only works for one window
        let windowIDs = NSApplication.shared.windows.map(\.windowNumber).filter { $0 != self.view.window!.windowNumber }

        // TODO: Figure out the correct frame for this call. self.view.window.frame isn't enough, `Son of Grab` Apple sample code will probably help
        let imageRef = CGWindowListCreateImage(.zero,
                                               CGWindowListOption.optionIncludingWindow,
                                               CGWindowID(windowIDs.first!),
                                               [])

        let image = NSImage(cgImage: imageRef!, size: self.view.window!.frame.size)

        if let url = TwoFactorCodeDetector.secret(for: image) {
            NotificationCenter.default.post(name: Notification.Name("Got2FA"), object: nil, userInfo: ["secret": url.absoluteString])
            self.view.window?.close()
        } else {
            self.view.window?.close()
        }
    }

}

public extension NSBezierPath {

    public var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        for i in 0 ..< self.elementCount {
            let type = self.element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo: path.move(to: points[0])
            case .lineTo: path.addLine(to: points[0])
            case .curveTo: path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath: path.closeSubpath()
            }
        }
        return path
    }

}
