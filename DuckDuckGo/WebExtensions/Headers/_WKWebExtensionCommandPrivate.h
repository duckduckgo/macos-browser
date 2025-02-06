#import "_WKWebExtensionCommand.h"

@interface _WKWebExtensionCommand ()

@property (nonatomic, readonly, copy) NSString *_shortcut;

- (BOOL)_matchesEvent:(NSEvent *)event;

@end
