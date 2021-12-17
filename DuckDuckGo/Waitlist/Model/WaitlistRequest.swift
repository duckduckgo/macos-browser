//
//  WaitlistRequest.swift
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

struct MacWaitlistRedeemSuccessResponse: Decodable {
    var hasExpectedStatusMessage: Bool {
        return status == "redeemed"
    }

    let status: String
}

enum MacWaitlistRedeemError: Error {
    case redemptionError
}

protocol MacWaitlistRequest {
    
    func unlock(with inviteCode: String,
                completion: @escaping (Result<MacWaitlistRedeemSuccessResponse, MacWaitlistRedeemError>) -> Void)
    
}

struct MacWaitlistAPIRequest: MacWaitlistRequest {
        
    private let endpoint: URL
    
    init(endpoint: URL? = nil) {
        if let endpoint = endpoint {
            self.endpoint = endpoint
        } else {
            #if DEBUG || REVIEW
            self.endpoint = URL.redeemMacWaitlistInviteCode(endpoint: .developmentEndpoint)
            #else
            self.endpoint = URL.redeemMacWaitlistInviteCode(endpoint: .productionEndpoint)
            #endif
        }
    }
    
    func unlock(with inviteCode: String,
                completion: @escaping (Result<MacWaitlistRedeemSuccessResponse, MacWaitlistRedeemError>) -> Void) {
        
        let parameters = [ "code": inviteCode ]
        
        APIRequest.request(url: endpoint, method: .post, parameters: parameters, callBackOnMainThread: true) { response, _ in
            let decoder = JSONDecoder()

            if let responseData = response?.data,
               let decodedResponse = try? decoder.decode(MacWaitlistRedeemSuccessResponse.self, from: responseData) {
                completion(.success(decodedResponse))
            } else {
                completion(.failure(.redemptionError))
            }
        }
        
    }
    
}
