//
//  _WKDownload.h
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

// https://github.com/WebKit/WebKit/blob/a6d132292cdb5975a0082a952a270ca1f7b2f7ac/Source/WebKit/UIProcess/API/Cocoa/_WKDownload.mm
@interface _WKDownload : NSObject <NSCopying>

- (void)cancel;

- (void)publishProgressAtURL:(NSURL *)URL;

@property (nonatomic, readonly) NSURLRequest *request;
@property (nonatomic, readonly, weak) WKWebView *originatingWebView;
@property (nonatomic, readonly, copy) NSArray<NSURL *> *redirectChain;
@property (nonatomic, readonly) BOOL wasUserInitiated;
@property (nonatomic, readonly) NSData *resumeData;
@property (nonatomic, readonly) WKFrameInfo *originatingFrame;

@end
