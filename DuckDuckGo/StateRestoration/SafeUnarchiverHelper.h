//
//  SafeUnarchiverHelper.h
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

#ifndef SafeUnarchiverHelper_h
#define SafeUnarchiverHelper_h

@interface SafeUnarchiverHelper : NSObject <NSSecureCoding>

typedef void (^Callback)(NSCoder * _Nonnull);
typedef void (^Job)(Callback _Nonnull);
+ (void)withNonescapingCallback:(NS_NOESCAPE Callback _Nonnull )callback do:(Job _Nonnull)job;

@end

#endif /* SafeUnarchiverHelper_h */
