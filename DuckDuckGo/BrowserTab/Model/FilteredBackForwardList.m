//
//  FilteredBackForwardList.m
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

#import "FilteredBackForwardList.h"

@interface WKBackForwardList (private)
- (void)_removeAllItems;
- (void)_clear;
@end

@interface FilteredBackForwardListWrapper : NSObject
@property (nonatomic, strong) WKBackForwardList * list;
@property (nonatomic, strong) NSMapTable * invalidatedItems;

- (instancetype)initWithBackForwardList:(WKBackForwardList *)list;
@end

@implementation FilteredBackForwardList

+ (id)allocWithZone:(struct _NSZone *)zone {
    // Replacing self inherited from WKBackForwardList with forwarding FilteredBackForwardListWrapper inherited from NSObject
    // as real WKBackForwardList calls _list->~WebBackForwardList() on dealloc where _list is NULL
    return (id)[FilteredBackForwardListWrapper allocWithZone:zone];
}

- (id)initWithBackForwardList:(WKBackForwardList *)list {
    assert("invalid flow");
    return nil;
}

- (void)invalidateBackForwardListItem:(WKBackForwardListItem *)item {
    assert("invalid flow");
}

- (NSArray<WKBackForwardListItem *> *)invalidatedBackForwardListItems {
    assert("invalid flow");
    return nil;
}

@end

@implementation FilteredBackForwardListWrapper

- (instancetype)initWithBackForwardList:(WKBackForwardList *)list {
    self = [super init];
    if (self) {
        _list = list;
        _invalidatedItems = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory valueOptions:NSPointerFunctionsStrongMemory];
    }
    return self;
}

- (WKBackForwardListItem *)backItem {
    WKBackForwardListItem * backItem = [_list backItem];
    if (!backItem) {
        return nil;
    }
    if ([_invalidatedItems objectForKey:backItem] == nil) {
        return backItem;
    }
    for (WKBackForwardListItem * backItem in [_list backList]) {
        if ([_invalidatedItems objectForKey:backItem] == nil) {
            return backItem;
        }
    }
    return nil;
}

- (WKBackForwardListItem *)forwardItem {
    WKBackForwardListItem * forwardItem = [_list forwardItem];
    if (!forwardItem) {
        return nil;
    }
    if ([_invalidatedItems objectForKey:forwardItem] == nil) {
        return forwardItem;
    }
    for (WKBackForwardListItem * forwardItem in [_list forwardList]) {
        if ([_invalidatedItems objectForKey:forwardItem] == nil) {
            return forwardItem;
        }
    }
    return nil;
}

- (WKBackForwardListItem *)currentItem {
    return [_list currentItem];
}

- (NSArray<WKBackForwardListItem *> *)backList {
    NSArray *backList = [_list backList];
    __typeof(_invalidatedItems) invalidatedItems = _invalidatedItems;

    return [backList filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(WKBackForwardListItem * item, NSDictionary * bindings) {
        return [invalidatedItems objectForKey:item] == nil;
    }]];
}

- (NSArray<WKBackForwardListItem *> *)forwardList {
    NSArray *forwardList = [_list forwardList];
    __typeof(_invalidatedItems) invalidatedItems = _invalidatedItems;

    return [forwardList filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(WKBackForwardListItem * item, NSDictionary * bindings) {
        return [invalidatedItems objectForKey:item] == nil;
    }]];
}

- (void)_clear {
    [_list _clear];
}

- (void)_removeAllItems {
    [_list _removeAllItems];
}

- (void)invalidateBackForwardListItem:(WKBackForwardListItem *)item {
    [_invalidatedItems setObject:@YES forKey:item];
}

- (NSArray<WKBackForwardListItem *> *)invalidatedBackForwardListItems {
    NSMutableArray *result = [NSMutableArray array];
    for (WKBackForwardListItem *item in _invalidatedItems) {
        [result addObject:item];
    }
    return result;
}

// Forward invocation to real list in case of not recognized selector
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [_list methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:_list];
}

@end
