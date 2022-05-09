//
//  FirefoxBerkeleyDatabaseReader.m
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

#import "FirefoxBerkeleyDatabaseReader.h"

#include <sys/types.h>
#include <db.h>
#include <fcntl.h>
#include <limits.h>

@implementation FirefoxBerkeleyDatabaseReader

+ (void)readDatabase:(NSString *)databasePath {
    const char *path = [databasePath cStringUsingEncoding:NSUTF8StringEncoding];
    NSLog(@"Opening database at path: %s", path);
    DB *db = dbopen(path, O_RDONLY, O_RDONLY, DB_HASH, NULL);
    NSLog(@"Opened database at path: %s", path);
    
    DBT key, data;
    
    while (db->seq(db, &key, &data, R_NEXT) == 0) {
        // NSString *keyString = [NSString stringWithCharacters:key.data length:key.size];
        NSData *objcKeyData = [NSData dataWithBytes:key.data length:key.size];
        NSData *objcDataData = [NSData dataWithBytes:data.data length:data.size];
        NSString *keyString = [[NSString alloc] initWithData:objcKeyData encoding:NSUTF8StringEncoding];
        NSLog(@"Got key length %d, data length %d", key.size, data.size);
        NSLog(@"Got key %@", keyString);
    }
    
    db->close(db);
    
    NSLog(@"Reading database");
}

@end
