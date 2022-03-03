//
//  RecentlyVisitedView.swift
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

import SwiftUI
import Lottie

extension HomePage.Views {

struct RecentlyVisited: View {

    let dateFormatter = RelativeDateTimeFormatter()

    @EnvironmentObject var model: HomePage.Models.RecentlyVisitedModel

    var body: some View {

        VStack {
            ProtectionSummary()

            if #available(macOS 11, *) {
                LazyVStack {
                    ForEach(model.recentSites, id: \.domain) {
                        RecentlyVisitedSite(site: $0)
                    }
                }
            } else {
                VStack {
                    ForEach(model.recentSites, id: \.domain) {
                        RecentlyVisitedSite(site: $0)
                    }
                }
            }
            
        }.padding(.bottom, 24)

    }

}

struct RecentlyVisitedSite: View {

    @EnvironmentObject var model: HomePage.Models.RecentlyVisitedModel
    @ObservedObject var site: HomePage.Models.RecentlyVisitedSiteModel

    @State var isHovering = false
    @State var isBurning = false
    @State var isHidden = false

    @State var isFavorite = false

    var body: some View {
        ZStack {

            RoundedRectangle(cornerRadius: 8)
                .fill(Color("HomePageBackgroundColor"))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 1)
                .visibility(isHovering ? .visible : .gone)

            HStack(alignment: .top) {

                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.gray)
                        .frame(width: 32, height: 32)

                    Rectangle()
                        .fill(.gray)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }

                VStack(alignment: .leading) {

                    HStack {
                        Text(site.domain)
                            .font(.system(size: 15, weight: .bold, design: .default))

                        Spacer()

                        HoverButton(imageName: isFavorite ? "FavoriteFilled" : "Favorite") {
                            isFavorite = model.toggleFavoriteSite(site)
                        }
                        .tooltip("Add to Favorites")

                        HoverButton(imageName: "Burn") {
                            isHovering = false
                            isBurning = true
                            withAnimation(.default.delay(0.4)) {
                                isHidden = true
                            }
                        }
                        .tooltip("Burn History and Site data")

                    }

                    Text("Some trackers were blocked")
                        .font(.system(size: 13))

                }.padding(.bottom, 12)

                Spacer()

            }
            .padding([.leading, .trailing, .top], 12)
            .visibility(isHidden ? .invisible : .visible)

            FireAnimation()
                .cornerRadius(8)
                .visibility(isBurning ? .visible : .gone)
                .zIndex(100)
                .onAppear {
                    withAnimation(.default.delay(1.0)) {
                        isBurning = false
                    }
                }
                .onDisappear {
                    withAnimation {
                        model.burn(site)
                    }
                }

        }
        .onHover {
            isHovering = $0
        }
        .onAppear(perform: {
            isFavorite = model.isFavoriteSite(site)
        })
        .frame(maxWidth: .infinity)

    }

}

struct FireAnimation: NSViewRepresentable {

    static let animation = Animation.named("01_Fire_really_small")

    func makeNSView(context: NSViewRepresentableContext<FireAnimation>) -> NSView {
        let view = NSView(frame: .zero)

        let animationView = AnimationView()
        animationView.animation = Self.animation
        animationView.contentMode = .scaleAspectFill
        animationView.loopMode = .playOnce
        animationView.play()

        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor),
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])

        return view
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {
    }

}

}

extension View {

    @ViewBuilder func tooltip(_ message: String) -> some View {
        if #available(macOS 11, *) {
            self.help(message)
        } else {
            self
        }
    }

}
