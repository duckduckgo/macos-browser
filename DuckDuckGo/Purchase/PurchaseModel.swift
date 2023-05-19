//
//  PurchaseModel.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import Combine
import StoreKit

@available(macOS 12.0, *)
public final class PurchaseModel: ObservableObject {

//    @ObservedObject var manager: PurchaseManager

    @Published var products: [Product]

    init(products: [Product] = []) {
//        self.manager = manager
        self.products = products
    }

    func buy(_ product: Product) {
        print("Buying \(product.displayName)")

    }

}
