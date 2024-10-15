//
//  VPNGuardian.m
//  NetworkProtectionMac
//
//  Created by ddg on 10/15/24.
//

#import "VPNGuardian.h"
#import "SystemConfiguration/SCDynamicStoreCopyDHCPInfo.h"

@implementation VPNGuardian

- (NSData *)getDHCPOption121 {
    SCDynamicStoreRef store = SCDynamicStoreCreate(NULL, CFSTR("DHCPOptionDetector"), NULL, NULL);
    if (!store) return nil;

    // Create a key pattern to match the relevant network service entity for IPv4 DHCP
    CFStringRef dhcpPattern = SCDynamicStoreKeyCreateNetworkServiceEntity(NULL,
                                                                          kSCDynamicStoreDomainState, // domain = "State:"
                                                                          kSCCompAnyRegex,            // serviceID = "[^/]+" (1 or more non-slash chars)
                                                                          kSCEntNetDHCP               // entity = "DHCP"
                                                                          );

    CFDictionaryRef dhcpInfo = SCDynamicStoreCopyDHCPInfo(store, NULL);
    if (!dhcpInfo) {
        CFRelease(dhcpPattern);
        CFRelease(store);
        return nil;
    }

    CFDataRef optionData = DHCPInfoGetOptionData(dhcpInfo, 121);
    NSData *result = nil;

    if (optionData) {
        CFRetain(optionData);
        result = CFBridgingRelease(optionData);
    }

    CFRelease(dhcpInfo);
    CFRelease(dhcpPattern);
    CFRelease(store);

    return result;
}

@end
