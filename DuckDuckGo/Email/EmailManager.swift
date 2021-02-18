//
//  EmailManager.swift
//  DuckDuckGo
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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


//TODO refactor out APIRequest, pixels
//pixels only on signout and signin, can do a delegate probs
//also emailAliasGenerated...
//TODO how do we handle the auto creds thing? Temporary, so maybe don't worry about it so much
//TOdo, I should probs implement this as a local package for testing

public protocol EmailManagerStorage: class {
    func getUsername() -> String?
    func getToken() -> String?
    func getAlias() -> String?
    func store(token: String, username: String)
    func store(alias: String)
    func deleteAlias()
    func deleteAll()
}

public protocol EmailManagerAliasPermissionDelegate: class {
    func emailManager(_ emailManager: EmailManager, didRequestPermissionToProvideAlias alias: String, completionHandler: @escaping (Bool) -> Void)
}

public protocol EmailManagerRequestDelegate: class {
    func emailManager(_ emailManager: EmailManager,
                      didRequestAliasWithURL url: URL,
                      method: String,
                      headers: [String: String],
                      timeoutInterval: TimeInterval,
                      completion: @escaping (Data?, Error?) -> Void)
}

public extension Notification.Name {
    static let emailDidSignIn = Notification.Name("com.duckduckgo.browserServicesKit.EmailDidSignIn")
    static let emailDidSignOut = Notification.Name("com.duckduckgo.browserServicesKit.EmailDidSignOut")
}

public enum AliasRequestError: Error {
    case noDataError
    case signedOut
    case invalidResponse
    case userRefused
    case permissionDelegateNil
}

private struct EmailUrls {
    private struct Url {
        static let emailAlias = "https://quack.duckduckgo.com/api/email/addresses"
        static let emailLandingPage = "https://quack.duckduckgo.com/email-protection"
        static let emailAuthenticationHosts = ["quack.duckduckgo.com", "quackdev.duckduckgo.com"]
    }
    
    var emailLandingPage: URL {
        return URL(string: Url.emailLandingPage)!
    }
    
    func shouldAuthenticateWithEmailCredentials(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return Url.emailAuthenticationHosts.contains(host)
    }
    
    var emailAliasAPI: URL {
        return URL(string: Url.emailAlias)!
    }
}

public typealias AliasCompletion = (String?, AliasRequestError?) -> Void

public class EmailManager {
    
    private static let emailDomain = "duck.com"
    
    private let storage: EmailManagerStorage
    public weak var aliasPermissionDelegate: EmailManagerAliasPermissionDelegate?
    public weak var requestDelegate: EmailManagerRequestDelegate?
    
    private lazy var emailUrls = EmailUrls()
    private lazy var aliasAPIURL = emailUrls.emailAliasAPI
    
    private var username: String? {
        storage.getUsername()
    }
    private var token: String? {
        storage.getToken()
    }
    private var alias: String? {
        storage.getAlias()
    }
    
    public var isSignedIn: Bool {
        return token != nil && username != nil
    }
    
    public var userEmail: String? {
        guard let username = username else { return nil }
        return username + "@" + EmailManager.emailDomain
    }
    
    public init(storage: EmailManagerStorage = EmailKeychainManager()) {
        self.storage = storage
    }
    
    public func signOut() {
        storage.deleteAll()
        NotificationCenter.default.post(name: .emailDidSignOut, object: self)
        //TODO Pixel.fire(pixel: .emailUserSignedOut)
    }
    
    public func getAliasEmailIfNeededAndConsume(timeoutInterval: TimeInterval = 4.0, completionHandler: @escaping AliasCompletion) {
        getAliasEmailIfNeeded(timeoutInterval: timeoutInterval) { [weak self] newAlias, error in
            completionHandler(newAlias, error)
            if error == nil {
                self?.consumeAliasAndReplace()
            }
        }
    }
}

extension EmailManager: EmailUserScriptDelegate {
    public func emailUserScriptDidRequestSignedInStatus(emailUserScript: EmailUserScript) -> Bool {
        isSignedIn
    }
    
    public func emailUserScript(_ emailUserScript: EmailUserScript,
                                didRequestAliasAndRequiresUserPermission requiresUserPermission: Bool,
                                completionHandler: @escaping AliasCompletion) {
            
        getAliasEmailIfNeeded { [weak self] newAlias, error in
            guard let newAlias = newAlias, error == nil, let self = self else {
                completionHandler(nil, error)
                return
            }
            
            if requiresUserPermission {
                guard let delegate = self.aliasPermissionDelegate else {
                    assertionFailure("EmailUserScript requires permission to provide Alias")
                    completionHandler(nil, .permissionDelegateNil)
                    return
                }
                
                delegate.emailManager(self, didRequestPermissionToProvideAlias: newAlias) { [weak self] permissionsGranted in
                    if permissionsGranted {
                        completionHandler(newAlias, nil)
                        self?.consumeAliasAndReplace()
                    } else {
                        completionHandler(nil, .userRefused)
                    }
                }
            } else {
                completionHandler(newAlias, nil)
                self.consumeAliasAndReplace()
            }
        }
    }
    
    public func emailUserScript(_ emailUserScript: EmailUserScript, didRequestStoreToken token: String, username: String) {
        //TODO Pixel.fire(pixel: .emailUserSignedIn)
        storeToken(token, username: username)
        NotificationCenter.default.post(name: .emailDidSignIn, object: self)
    }
}

// Token Management
private extension EmailManager {
    func storeToken(_ token: String, username: String) {
        storage.store(token: token, username: username)
        fetchAndStoreAlias()
    }
}

// Alias managment
private extension EmailManager {
    
    struct EmailAliasResponse: Decodable {
        let address: String
    }
    
    typealias HTTPHeaders = [String: String]
    
    var aliasHeaders: HTTPHeaders {
        guard let token = token else {
            return [:]
        }
        return ["Authorization": "Bearer " + token]
    }
    
    func consumeAliasAndReplace() {
        storage.deleteAlias()
        fetchAndStoreAlias()
    }
    
    func getAliasEmailIfNeeded(timeoutInterval: TimeInterval = 4.0, completionHandler: @escaping AliasCompletion) {
        if let alias = alias {
            completionHandler(emailFromAlias(alias), nil)
            return
        }
        fetchAndStoreAlias(timeoutInterval: timeoutInterval) { [weak self] newAlias, error in
            guard let newAlias = newAlias, error == nil  else {
                completionHandler(nil, error)
                return
            }
            completionHandler(self?.emailFromAlias(newAlias), nil)
        }
    }
    
    func fetchAndStoreAlias(timeoutInterval: TimeInterval = 60.0, completionHandler: AliasCompletion? = nil) {
        fetchAlias(timeoutInterval: timeoutInterval) { [weak self] alias, error in
            guard let alias = alias, error == nil else {
                completionHandler?(nil, error)
                return
            }
            // Check we haven't signed out whilst waiting
            // if so we don't want to save sensitive data
            guard let self = self, self.isSignedIn else {
                completionHandler?(nil, .signedOut)
                return
            }
            self.storage.store(alias: alias)
            completionHandler?(alias, nil)
        }
    }

    func fetchAlias(timeoutInterval: TimeInterval = 60.0, completionHandler: AliasCompletion? = nil) {
        guard isSignedIn else {
            completionHandler?(nil, .signedOut)
            return
        }
        
        requestDelegate?.emailManager(self, didRequestAliasWithURL: aliasAPIURL, method: "POST", headers: aliasHeaders, timeoutInterval: timeoutInterval) { data, error in
            guard let data = data, error == nil else {
                completionHandler?(nil, .noDataError)
                return
            }
            do {
                let decoder = JSONDecoder()
                let alias = try decoder.decode(EmailAliasResponse.self, from: data).address
                //TODO Pixel.fire(pixel: .emailAliasGenerated)
                completionHandler?(alias, nil)
            } catch {
                completionHandler?(nil, .invalidResponse)
            }
        }
    }
    
    func emailFromAlias(_ alias: String) -> String {
        return alias + "@" + EmailManager.emailDomain
    }
}
