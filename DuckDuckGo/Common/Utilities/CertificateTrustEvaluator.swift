//
//  CertificateTrustEvaluator.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

protocol CertificateTrustEvaluating {
    func evaluateCertificateTrust(trust: SecTrust?) async -> Bool?
}

struct CertificateTrustEvaluator: CertificateTrustEvaluating {
    func evaluateCertificateTrust(trust: SecTrust?) async -> Bool? {
        var error: CFError?
        guard let trust = trust else { return nil }
        let result = SecTrustEvaluateWithError(trust, &error)
        return result
    }
}
