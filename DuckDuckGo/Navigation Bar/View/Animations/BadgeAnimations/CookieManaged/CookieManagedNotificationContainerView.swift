//
//  CookieManagedNotificationContainerView.swift
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

import Foundation
import SwiftUI

final class CookieNotificationAnimationModel: ObservableObject {
    static let duration: CGFloat = 1.5
    static let halfDuration = duration / 2
    static let secondPhaseDelay = halfDuration
    
    enum AnimationState {
        case unstarted
        case firstPhase
        case secondPhase
    }
    
    @Published var state: AnimationState = .unstarted
}

final class BadgeNotificationAnimationModel: ObservableObject {
    static let duration: CGFloat = 0.8
    static let secondPhaseDelay = 3.0
    
    enum AnimationState {
        case unstarted
        case expanded
        case retracted
    }
    
    @Published var state: AnimationState = .unstarted
}

final class CookieManagedNotificationContainerView: NSView, NotificationBarViewAnimated {
    private let cookieAnimationModel = CookieNotificationAnimationModel()
    private let badgeAnimationModel = BadgeNotificationAnimationModel()
    
    private lazy var hostingView: NSHostingView<CookieManagedNotificationView> = {
        let view = NSHostingView(rootView:
                                    CookieManagedNotificationView(animationModel: cookieAnimationModel,
                                                                  badgeAnimationModel: badgeAnimationModel))
        view.frame = bounds
        return view
    }()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        addSubview(hostingView)
        setupConstraints()
    }
    
    private func setupConstraints() {
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor)
        ])
    }
    
    func startAnimation(_ completion: @escaping () -> Void) {
        print("START!")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.startCookieAnimation()
            self.startBadgeAnimation()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            completion()
        }
    }
    
    private func startBadgeAnimation() {
        badgeAnimationModel.state = .expanded
        DispatchQueue.main.asyncAfter(deadline: .now() + BadgeNotificationAnimationModel.secondPhaseDelay) {
            self.badgeAnimationModel.state = .retracted
        }
    }
    
    private func startCookieAnimation() {
        cookieAnimationModel.state = .firstPhase
        DispatchQueue.main.asyncAfter(deadline: .now() + CookieNotificationAnimationModel.secondPhaseDelay) {
            self.cookieAnimationModel.state = .secondPhase
        }
    }
    
    deinit {
        print("BUYE")
    }
}
