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

struct MacWaitlistRedeemFailureResponse: Decodable {
    let error: String
}

enum MacWaitlistRedeemError: Error {
    case invalidInviteCode
    case alreadyRedeemedInviteCode
    case unknownError
}

protocol MacWaitlistRequest {
    
    func unlock(with inviteCode: String,
                completion: @escaping (Result<MacWaitlistRedeemSuccessResponse, MacWaitlistRedeemError>) -> Void)
    
}

struct MacWaitlistAPIRequest: MacWaitlistRequest {
    
    static let developmentEndpoint = URL(string: "https://quackdev.duckduckgo.com/api/auth/invites/")!
    static let productionEndpoint = URL(string: "https://quack.duckduckgo.com/api/auth/invites/")!
    
    private let endpoint: URL
    
    init(endpoint: URL? = nil) {
        if let endpoint = endpoint {
            self.endpoint = endpoint
        } else {
            #if DEBUG
            self.endpoint = Self.developmentEndpoint
            #else
            #warning("Change this to production later")
            self.endpoint = Self.developmentEndpoint
            #endif
        }
    }
    
    func unlock(with inviteCode: String,
                completion: @escaping (Result<MacWaitlistRedeemSuccessResponse, MacWaitlistRedeemError>) -> Void) {
        
        let redeemURL = self.endpoint.appendingPathComponent("macosbrowser").appendingPathComponent("redeem")
        let parameters = [ "code": inviteCode ]
        
        APIRequest.request(url: redeemURL, method: .post, parameters: parameters, callBackOnMainThread: true) { response, _ in
            let decoder = JSONDecoder()

            if let responseData = response?.data,
               let decodedResponse = try? decoder.decode(MacWaitlistRedeemSuccessResponse.self, from: responseData) {
                completion(.success(decodedResponse))
            } else {
                completion(.failure(.unknownError))
            }
        }
        
    }
    
}
