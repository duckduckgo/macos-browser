//
//  WKWebView+Download.m
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

#import "WKWebView+Download.h"

@implementation WKWebView (Download)

- (void)macos_11_3_startDownload:(NSURLRequest *)request completionHandler:(void(^)(id))completion {
    [self performSelector:@selector(startDownloadUsingRequest:completionHandler:) withObject:request withObject:completion];
}

- (void)macos_11_3_resumeDownload:(NSData *)resumeData completionHandler:(void(^)(id))completion {
    [self performSelector:@selector(resumeDownloadFromResumeData:completionHandler:) withObject:resumeData withObject:completion];
}

@end
