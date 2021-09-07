//
//  WebKitDownloadDelegate.h
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

#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

#ifndef __MAC_11_3

typedef NS_ENUM(NSInteger, WKDownloadRedirectPolicy) {
    WKDownloadRedirectPolicyCancel,
    WKDownloadRedirectPolicyAllow,
} NS_SWIFT_NAME(WKDownload.RedirectPolicy);

#endif

@protocol WebKitDownload;

typedef NS_ENUM(NSInteger, WebKitDownloadRedirectPolicy) {
    WebKitDownloadRedirectPolicyCancel,
    WebKitDownloadRedirectPolicyAllow,
};

@protocol WebKitDownloadDelegate <NSObject>
@required
- (void)download:(id <WebKitDownload>)download decideDestinationUsingResponse:(NSURLResponse * _Nullable)response suggestedFilename:(NSString *)suggestedFilename completionHandler:(void (^)(NSURL * _Nullable destination))completionHandler;

@optional
- (void)download:(id <WebKitDownload>)download willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request decisionHandler:(void (^)(WebKitDownloadRedirectPolicy))decisionHandler;
- (void)download:(id <WebKitDownload>)download didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler;
- (void)download:(id <WebKitDownload>)download didReceiveData:(uint64_t)length;
- (void)downloadDidFinish:(id <WebKitDownload>)download;
- (void)download:(id <WebKitDownload>)download didFailWithError:(NSError *)error resumeData:(NSData * _Nullable)resumeData;

@end

NS_ASSUME_NONNULL_END
